Shader "Custom/PolishedRustBP"
{
    Properties
    {
        _LightIntensity  ("Light Intensity",        Color)   = (1,1,1,1)
        _LightPosition_w ("Light Position (World)", Vector)  = (0,5,0,1)
        _AmbientLight    ("Ambient Light",          Color)   = (0.1,0.1,0.1,1)
        _MaterialKa      ("Material Ka",            Vector)  = (0.2,0.2,0.2,0)

        // Dos especulares distintos: metal pulido vs oxido mate
        _KsMetal         ("Ks metal pulido",        Vector)  = (0.9,0.9,0.9,0)
        _KsRust          ("Ks oxido",               Vector)  = (0.05,0.05,0.05,0)
        _nMetal          ("n metal pulido",         Float)   = 128.0
        _nRust           ("n oxido",                Float)   = 4.0

        // Colores
        _MetalColor      ("Color metal base",       Color)   = (0.7, 0.7, 0.75, 1)
        _MetalColor2     ("Color metal oscuro",     Color)   = (0.4, 0.4, 0.45, 1)
        _RustColor1      ("Color oxido claro",      Color)   = (0.6, 0.25, 0.05, 1)
        _RustColor2      ("Color oxido oscuro",     Color)   = (0.25, 0.08, 0.02, 1)

        _MetalScale      ("Escala general",         Float)   = 6.0
        _BumpStrength    ("Fuerza del relieve",     Float)   = 3.0
        _Octaves         ("Octavas del fractal",    Range(1,6)) = 5

        // Control del oxido
        _RustAmount      ("Cantidad de oxido",      Range(0,1)) = 0.5
        _RustSharpness   ("Nitidez del oxido",      Float)   = 3.0
        _PitDepth        ("Profundidad picaduras",  Float)   = 2.0

        // Control del metal pulido
        _PolishAmount    ("Brillo del pulido",      Range(0,1)) = 0.8
        _ScratchFreq     ("Frecuencia de rayones",  Float)   = 12.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vertexShader
            #pragma fragment fragmentShader
            #include "UnityCG.cginc"

            float4 _LightIntensity;
            float4 _LightPosition_w;
            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _KsMetal;
            float4 _KsRust;
            float  _nMetal;
            float  _nRust;
            float4 _MetalColor;
            float4 _MetalColor2;
            float4 _RustColor1;
            float4 _RustColor2;
            float  _MetalScale;
            float  _BumpStrength;
            int    _Octaves;
            float  _RustAmount;
            float  _RustSharpness;
            float  _PitDepth;
            float  _PolishAmount;
            float  _ScratchFreq;

            struct vertexData
            {
                float4 position : POSITION;
                float3 normal   : NORMAL;
                float2 uv       : TEXCOORD0;
            };

            struct v2f
            {
                float4 position   : SV_POSITION;
                float4 position_w : TEXCOORD0;
                float3 normal_w   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
            };

            // ── Utilidades ────────────────────────────────────────────

            float2 hash2(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)),
                           dot(p, float2(269.5, 183.3)));
                return frac(sin(p) * 43758.5453);
            }

            float hash1(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // ── Perlin ────────────────────────────────────────────────
            // Controla la distribución general del óxido y las
            // variaciones de tono del metal

            float2 gradiente(float2 cell)
            {
                float angle = hash1(cell) * 2.0 * UNITY_PI;
                return float2(cos(angle), sin(angle));
            }

            float smoothFade(float t)
            {
                return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
            }

            float perlin(float2 uv)
            {
                float2 cell  = floor(uv);
                float2 local = frac(uv);

                float2 g00 = gradiente(cell + float2(0,0));
                float2 g10 = gradiente(cell + float2(1,0));
                float2 g01 = gradiente(cell + float2(0,1));
                float2 g11 = gradiente(cell + float2(1,1));

                float v00 = dot(g00, local - float2(0,0));
                float v10 = dot(g10, local - float2(1,0));
                float v01 = dot(g01, local - float2(0,1));
                float v11 = dot(g11, local - float2(1,1));

                float2 fade = float2(smoothFade(local.x), smoothFade(local.y));
                return lerp(lerp(v00, v10, fade.x),
                            lerp(v01, v11, fade.x), fade.y);
            }

            float perlinFBM(float2 uv)
            {
                float value     = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;

                for (int o = 0; o < _Octaves; o++)
                {
                    value     += amplitude * perlin(uv * frequency);
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }

                return value * 0.5 + 0.5;
            }

            // ── Worley ────────────────────────────────────────────────
            // Genera las picaduras y cráteres del óxido

            float2 worley(float2 uv)
            {
                float2 cell  = floor(uv);
                float2 local = frac(uv);
                float  F1 = 8.0, F2 = 8.0;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 rndPoint = hash2(cell + neighbor);
                        float  dist     = length(neighbor + rndPoint - local);

                        if (dist < F1) { F2 = F1; F1 = dist; }
                        else if (dist < F2) { F2 = dist; }
                    }
                }

                return float2(F1, F2);
            }

            float worleyFBM(float2 uv)
            {
                float value     = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;

                for (int o = 0; o < _Octaves; o++)
                {
                    value     += amplitude * worley(uv * frequency).x;
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }

                return value;
            }

            // ── Rayones del metal pulido ──────────────────────────────
            // El metal pulido tiene rayones finos en una dirección
            // Los generamos con Perlin estirado horizontalmente

            float scratchNoise(float2 uv)
            {
                // Estiramos mucho en X para generar líneas finas horizontales
                float2 stretchedUV = float2(uv.x * _ScratchFreq, uv.y * 0.5);
                float scratches    = perlinFBM(stretchedUV);

                // pow() afila las líneas
                return pow(scratches, 6.0);
            }

            // ── Noise principal: Worley * Perlin ──────────────────────
            // Igual que en el shader de óxido pero ahora separamos
            // claramente las zonas oxidadas de las zonas pulidas
            // para poder aplicarles distintos parámetros de BP

            float rustNoise(float2 uv)
            {
                float P = perlinFBM(uv);
                float W = worleyFBM(uv * 2.0);

                // Worley * Perlin: picaduras concentradas en zonas oxidadas
                float rust = P * W;

                // Picaduras profundas
                float pits = pow(1.0 - W, _PitDepth);

                return saturate(rust + pits * _RustAmount);
            }

            float metalNoise(float2 uv)
            {
                // Variaciones suaves del tono del metal
                float P = perlinFBM(uv * 0.5);

                // Rayones del pulido
                float scratches = scratchNoise(uv) * _PolishAmount;

                return saturate(P + scratches * 0.3);
            }

            // ── Vertex Shader ─────────────────────────────────────────
            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position   = UnityObjectToClipPos(v.position);
                output.position_w = mul(unity_ObjectToWorld, v.position);
                output.normal_w   = UnityObjectToWorldNormal(v.normal);
                output.uv         = v.uv;
                return output;
            }

            // ── Fragment Shader ───────────────────────────────────────
            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float2 uv = f.uv * _MetalScale;

                float R = rustNoise(uv);
                float M = metalNoise(uv);
                float P = perlinFBM(uv);

                // ── Máscara de óxido ──────────────────────────────────
                // Define qué zonas son óxido y qué zonas son metal pulido
                // pow() con _RustSharpness hace la transición más abrupta
                float rustMask = saturate(pow(R * _RustAmount * 2.0,
                                              _RustSharpness));

                // ── Color ─────────────────────────────────────────────
                // Metal: variaciones sutiles de gris
                float3 metalColor = lerp(_MetalColor2.rgb, _MetalColor.rgb, M);

                // Óxido: dos tonos de naranja/marrón
                float3 rustColor  = lerp(_RustColor1.rgb, _RustColor2.rgb,
                                         saturate(R * 2.0));

                // Mezclamos metal y óxido según la máscara
                float3 finalColor = lerp(metalColor, rustColor, rustMask);

                // ── Normal perturbada ─────────────────────────────────
                // Las zonas oxidadas tienen más relieve que el metal pulido
                float eps  = 0.005;
                float R_dx = rustNoise(uv + float2(eps, 0)) - R;
                float R_dy = rustNoise(uv + float2(0, eps)) - R;

                float3 N = normalize(f.normal_w);
                float3 T = normalize(cross(N, float3(0, 1, 0)));
                float3 B = normalize(cross(N, T));

                float3 perturbedN = normalize(
                    N + _BumpStrength * rustMask * (R_dx * T + R_dy * B)
                );
                // Nota: multiplicamos por rustMask para que solo las zonas
                // oxidadas tengan relieve, el metal pulido queda liso

                // ── Blinn-Phong con parámetros interpolados ───────────
                // La clave de este shader: metal y óxido tienen
                // especulares completamente distintos
                //   metal pulido → Ks alto, n alto  (reflejo nítido)
                //   óxido        → Ks bajo, n bajo  (totalmente mate)
                float3 Ks = lerp(_KsMetal.rgb, _KsRust.rgb, rustMask);
                float  n  = lerp(_nMetal,      _nRust,      rustMask);

                float3 L = normalize(_LightPosition_w.xyz - f.position_w.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 H = (L + V) / 2.0;

                float3 ambient  = _MaterialKa.rgb * _AmbientLight.rgb;

                float3 diffuse  = finalColor * _LightIntensity.rgb
                                  * max(0.0, dot(perturbedN, L));

                // El especular varía suavemente entre metal y óxido
                float3 specular = Ks * _LightIntensity.rgb
                                  * pow(max(0.0, dot(perturbedN, H)), n);

                fixed4 fragColor;
                fragColor.rgb = ambient + diffuse + specular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}