Shader "Custom/FabricBP"
{
    Properties
    {
        _LightIntensity  ("Light Intensity",        Color)   = (1,1,1,1)
        _LightPosition_w ("Light Position (World)", Vector)  = (0,5,0,1)
        _AmbientLight    ("Ambient Light",          Color)   = (0.1,0.1,0.1,1)
        _MaterialKa      ("Material Ka",            Vector)  = (0.2,0.2,0.2,0)
        _MaterialKs      ("Material Ks",            Vector)  = (1,1,1,0)
        _Material_n      ("Material n (brillo)",    Float)   = 32
        _Color1          ("Color hilo 1",           Color)   = (0.8, 0.2, 0.1, 1)
        _Color2          ("Color hilo 2",           Color)   = (0.6, 0.1, 0.05, 1)
        _FabricScale     ("Escala de la tela",      Float)   = 10.0
        _BumpStrength    ("Fuerza del relieve",     Float)   = 2.0
        _Octaves         ("Octavas del fractal",    Range(1,6)) = 4
        // Gabor: controlan la dirección e intensidad de las fibras
        _Frequency       ("Frecuencia de fibras",  Float)   = 6.0
        _Anisotropy      ("Anisotropía (0=iso, 1=muy direccional)", Range(0,1)) = 0.8
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
            float4 _MaterialKs;
            float  _Material_n;
            float4 _Color1;
            float4 _Color2;
            float  _FabricScale;
            float  _BumpStrength;
            int    _Octaves;
            float  _Frequency;
            float  _Anisotropy;

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

            // Hash pseudo-aleatorio: dado un float2 devuelve un float2 en [0,1]
            float2 hash2(float2 p)
            {
                p = float2(
                    dot(p, float2(127.1, 311.7)),
                    dot(p, float2(269.5, 183.3))
                );
                return frac(sin(p) * 43758.5453);
            }

            // Hash que devuelve un escalar, para variar la fase de cada kernel
            float hash1(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // ── Gabor Noise ───────────────────────────────────────────
            // Un kernel de Gabor es una sinusoide modulada por una gaussiana:
            //   G(x) = exp(-π * a² * |x|²) * cos(2π * F * (x · d) + phase)
            // donde:
            //   a        = ancho de la gaussiana (cuán localizado es el kernel)
            //   F        = frecuencia de la sinusoide
            //   d        = dirección de las fibras
            //   phase    = fase aleatoria por celda
            //
            // Para simular tela usamos DOS direcciones (horizontal y vertical)
            // y las sumamos, generando el patrón de cruce de hilos.

            float gaborKernel(float2 x, float2 dir, float freq, float phase, float bandwidth)
            {
                // Gaussiana: localiza el kernel en el espacio
                float gaussian = exp(-UNITY_PI * bandwidth * bandwidth * dot(x, x));

                // Sinusoide direccional: genera las fibras
                float sinusoid = cos(2.0 * UNITY_PI * freq * dot(x, dir) + phase);

                return gaussian * sinusoid;
            }

            // Gabor noise estocastico: esparce kernels aleatoriamente en celdas
            // y los suma. Cada celda aporta un kernel con fase y posición random.
            float gaborNoise(float2 uv, float2 dir, float freq, float bandwidth)
            {
                float2 cell  = floor(uv);
                float2 local = frac(uv);
                float  value = 0.0;

                // Revisamos celda actual y vecinas
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor  = float2(x, y);
                        float2 cellCoord = cell + neighbor;

                        // Posición aleatoria del kernel dentro de la celda
                        float2 kernelPos = hash2(cellCoord);

                        // Fase aleatoria por celda
                        float phase = hash1(cellCoord + 7.3) * 2.0 * UNITY_PI;

                        // Vector desde el pixel al kernel
                        float2 diff = local - (neighbor + kernelPos);

                        value += gaborKernel(diff, dir, freq, phase, bandwidth);
                    }
                }

                return value;
            }

            // ── Gabor fBm ─────────────────────────────────────────────
            // Suma octavas de Gabor noise en DOS direcciones (trama y urdimbre)
            // para simular el cruce de hilos de la tela.
            float gaborFBM(float2 uv)
            {
                float value     = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                float bandwidth = 1.5;  // ancho de la gaussiana

                // Dirección horizontal (hilos de urdimbre)
                float2 dirH = float2(1.0, 0.0);
                // Dirección vertical (hilos de trama)
                float2 dirV = float2(0.0, 1.0);

                for (int o = 0; o < _Octaves; o++)
                {
                    float2 scaledUV = uv * frequency;

                    // Sumamos ambas direcciones
                    // _Anisotropy controla cuánto peso tiene cada dirección
                    float horizontal = gaborNoise(scaledUV, dirH, _Frequency, bandwidth);
                    float vertical   = gaborNoise(scaledUV, dirV, _Frequency, bandwidth);

                    // Mezclamos horizontal y vertical según anisotropía
                    // anisotropy=1 → muy marcadas las dos direcciones (tela gruesa)
                    // anisotropy=0 → isótropo (tela muy fina)
                    float combined = lerp(
                        (horizontal + vertical) * 0.5,
                        abs(horizontal) * abs(vertical),
                        _Anisotropy
                    );

                    value     += amplitude * combined;
                    frequency *= 2.0;
                    amplitude *= 0.5;
                    bandwidth *= 0.8;   // la gaussiana se achica en cada octava
                }

                // Normalizamos a [0,1]
                return value * 0.5 + 0.5;
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
                float2 uv = f.uv * _FabricScale;

                // Valor del Gabor fBm en este pixel
                float G = gaborFBM(uv);

                // ── Color de la tela ──────────────────────────────────
                // El patrón de cruce de hilos genera valores altos donde
                // los hilos se cruzan y bajos en los espacios entre ellos
                float3 fabricColor = lerp(_Color1.rgb, _Color2.rgb, G);

                // ── Normal perturbada ─────────────────────────────────
                float eps  = 0.005;
                float G_dx = gaborFBM(uv + float2(eps, 0)) - G;
                float G_dy = gaborFBM(uv + float2(0, eps)) - G;

                float3 N = normalize(f.normal_w);
                float3 T = normalize(cross(N, float3(0, 1, 0)));
                float3 B = normalize(cross(N, T));

                float3 perturbedN = normalize(
                    N + _BumpStrength * (G_dx * T + G_dy * B)
                );

                // ── Blinn-Phong ───────────────────────────────────────
                float3 L = normalize(_LightPosition_w.xyz - f.position_w.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 H = (L + V) / 2.0;

                // Ambiente
                float3 ambient  = _MaterialKa.rgb * _AmbientLight.rgb;

                // Difuso — usa el color de la tela como Kd
                float3 diffuse  = fabricColor * _LightIntensity.rgb
                                  * max(0.0, dot(perturbedN, L));

                // Especular
                float3 specular = _MaterialKs.rgb * _LightIntensity.rgb
                                  * pow(max(0.0, dot(perturbedN, H)), _Material_n);

                fixed4 fragColor;
                fragColor.rgb = ambient + diffuse + specular;
                fragColor.a   = 1.0;
                return fragColor;
            }

            ENDCG
        }
    }
}