Shader "Custom/WoolBP"
{
    Properties
    {
        _AmbientLight    ("Ambient Light",           Color)  = (1,1,1,1)
         _MaterialKa      ("Material Ka",            Vector)     = (0.3,0.3,0.3,0)
        _MaterialKs      ("Material Ks",            Vector)     = (0.02,0.02,0.02,0)
        _Material_n      ("Material n (brillo)",    Float)      = 3
        _Color1          ("Color lana base",        Color)      = (0.85, 0.55, 0.20, 1)
        _Color2          ("Color lana oscuro",      Color)      = (0.60, 0.32, 0.10, 1)
        _WoolScale       ("Escala del hilo",        Float)      = 18.0
        _TwistStrength   ("Fuerza de torsión",      Float)      = 3.5
        _FuzzScale       ("Escala de pelusa",       Float)      = 60.0
        _FuzzStrength    ("Fuerza de pelusa",       Range(0,1)) = 0.35
        _Octaves         ("Octavas del fractal",    Range(1,6)) = 3
        _Frequency       ("Frecuencia de fibras",   Float)      = 3.0
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
            #include "../LightingGlobals.cginc" 

            float4 _MaterialKa;
            float4 _AmbientLight;
            float4 _MaterialKs;
            float  _Material_n;
            float4 _Color1;
            float4 _Color2;
            float  _WoolScale;
            float  _TwistStrength;
            float  _FuzzScale;
            float  _FuzzStrength;
            int    _Octaves;
            float  _Frequency;

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
                p = float2(
                    dot(p, float2(127.1, 311.7)),
                    dot(p, float2(269.5, 183.3))
                );
                return frac(sin(p) * 43758.5453);
            }

            float hash1(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            // ── Gabor Kernel ──────────────────────────────────────────
            float gaborKernel(float2 x, float2 dir, float freq, float phase, float bandwidth)
            {
                float gaussian  = exp(-UNITY_PI * bandwidth * bandwidth * dot(x, x));
                float sinusoid  = cos(2.0 * UNITY_PI * freq * dot(x, dir) + phase);
                return gaussian * sinusoid;
            }

            float gaborNoise(float2 uv, float2 dir, float freq, float bandwidth)
            {
                float2 cell  = floor(uv);
                float2 local = frac(uv);
                float  value = 0.0;

                for (int y = -1; y <= 1; y++)
                for (int x = -1; x <= 1; x++)
                {
                    float2 neighbor  = float2(x, y);
                    float2 cellCoord = cell + neighbor;
                    float2 kernelPos = hash2(cellCoord);
                    float  phase     = hash1(cellCoord + 7.3) * 2.0 * UNITY_PI;
                    float2 diff      = local - (neighbor + kernelPos);
                    value += gaborKernel(diff, dir, freq, phase, bandwidth);
                }
                return value;
            }

            // ── Wool fBM ──────────────────────────────────────────────
            float woolFBM(float2 uv)
            {
                float value     = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                float bandwidth = 1.2;

                for (int o = 0; o < _Octaves; o++)
                {
                    float2 scaledUV = uv * frequency;

                    // Ángulo de torsión: varía con la posición v del UV
                    // Esto hace que la dirección del hilo rote a lo largo del eje
                    float twistAngle = uv.x * _TwistStrength * 0.2 + sin(uv.y * 2.0) * 0.3;
                    float2 dir = float2(cos(twistAngle), sin(twistAngle));

                    float fiber = gaborNoise(scaledUV, dir, _Frequency, bandwidth);

                    value     += amplitude * fiber;
                    frequency *= 2.0;
                    amplitude *= 0.5;
                    bandwidth *= 0.75;
                }

                return value * 0.5 + 0.5;
            }

            // ── Fuzz (pelusa) ─────────────────────────────────────────
            // Capa separada de alta frecuencia con dirección casi aleatoria
            // Simula las fibras sueltas que sobresalen del hilo de lana
            float fuzzNoise(float2 uv)
            {
                float2 scaledUV = uv * _FuzzScale;
                float2 cell     = floor(scaledUV);
                float2 local    = frac(scaledUV);
                float  value    = 0.0;

                for (int y = -1; y <= 1; y++)
                for (int x = -1; x <= 1; x++)
                {
                    float2 neighbor  = float2(x, y);
                    float2 cellCoord = cell + neighbor;

                    // Dirección aleatoria por celda — simula fibras sueltas en
                    // todas direcciones, no alineadas como en el hilo principal
                    float2 randDir = normalize(hash2(cellCoord + 3.7) * 2.0 - 1.0);
                    float  phase   = hash1(cellCoord + 1.1) * 2.0 * UNITY_PI;
                    float2 diff    = local - (neighbor + hash2(cellCoord));

                    value += gaborKernel(diff, randDir, 4.0, phase, 2.0);
                }

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
                float2 uv = f.uv * _WoolScale;

                // ── Patrón de lana ────────────────────────────────────────
                float W = woolFBM(uv);
                float Z = fuzzNoise(f.uv);

                float3 woolColor = lerp(_Color1.rgb, _Color2.rgb, W);
                woolColor = lerp(woolColor, _Color1.rgb * 1.15, Z * _FuzzStrength);
                woolColor = saturate(woolColor);

                // ── Vectores base ─────────────────────────────────────────
                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);

                // ── Acumulación de las 3 luces ────────────────────────────
                float3 totalDiffuse  = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                float3 L, lightColor;
                LightResult r;

                GetDirLight(L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, woolColor, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                GetPointLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, woolColor, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                GetSpotLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, woolColor, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}