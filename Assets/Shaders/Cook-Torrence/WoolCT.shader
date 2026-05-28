Shader "Custom/CookTorrence/WoolCT"
{
    Properties
    {
        _AmbientLight    ("Ambient Light",          Color)       = (0.2,0.2,0.2,1)
        _MaterialKa      ("Material Ka (ambiente)", Vector)      = (0.2,0.2,0.2,0)
        _MaterialKd      ("Material Kd (difuso)",   Vector)      = (0.6,0.6,0.6,0)
        _F0              ("F0 (reflectancia base)", Color)       = (0.04,0.04,0.04,1)
        _Roughness       ("Roughness",              Range(0,1))  = 0.5

        [Space]
        [Header(Wool Parameters)]
        _Color1          ("Color lana base",        Color)       = (0.85, 0.55, 0.20, 1)
        _Color2          ("Color lana oscuro",      Color)       = (0.60, 0.32, 0.10, 1)
        _WoolScale       ("Escala del hilo",        Float)       = 18.0
        _TwistStrength   ("Fuerza de torsi�n",      Float)       = 3.5
        _FuzzScale       ("Escala de pelusa",       Float)       = 60.0
        _FuzzStrength    ("Fuerza de pelusa",       Range(0,1))  = 0.35
        _Octaves         ("Octavas del fractal",    Range(1,6))  = 3
        _Frequency       ("Frecuencia de fibras",   Float)       = 3.0

        [Space]
        [Header(Metodos)]
        [IntRange] _DMethod ("D: 0=Blinn  1=Beckmann  2=GGX", Range(0,2)) = 0
        [IntRange] _GMethod ("G: 0=SmithGGX  1=SmithBeckmann", Range(0,1)) = 0
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

            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _MaterialKd;
            float4 _F0;
            float  _Roughness;
            int    _DMethod;
            int    _GMethod;

            // Wool parameters
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

            // --------------------- Utilidades de la lana (procedural) ---------------------
            float2 hash2(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return frac(sin(p) * 43758.5453);
            }

            float hash1(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

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

            float woolFBM(float2 uv)
            {
                float value     = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                float bandwidth = 1.2;
                for (int o = 0; o < _Octaves; o++)
                {
                    float2 scaledUV = uv * frequency;
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
                    float2 randDir = normalize(hash2(cellCoord + 3.7) * 2.0 - 1.0);
                    float  phase   = hash1(cellCoord + 1.1) * 2.0 * UNITY_PI;
                    float2 diff    = local - (neighbor + hash2(cellCoord));
                    value += gaborKernel(diff, randDir, 4.0, phase, 2.0);
                }
                return value * 0.5 + 0.5;
            }

            // --------------------- Funciones Cook-Torrance ---------------------
            float3 F_Schlick(float3 F0, float VdotH)
            {
                return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
            }

            float D_GGX(float NdotH, float roughness)
            {
                float a  = roughness * roughness;
                float a2 = a * a;
                float d  = (NdotH * NdotH * (a2 - 1.0) + 1.0);
                return a2 / (UNITY_PI * d * d);
            }

            float D_Beckmann(float NdotH, float roughness)
            {
                float a2     = max(roughness * roughness * roughness * roughness, 0.00001);
                float NdotH2 = max(NdotH * NdotH, 0.00001);
                float exponent = (NdotH2 - 1.0) / (a2 * NdotH2);
                return exp(exponent) / (UNITY_PI * a2 * NdotH2 * NdotH2);
            }

            float D_Blinn(float NdotH, float roughness)
            {
                float a2 = roughness * roughness * roughness * roughness;
                float ns = 2.0 / a2 - 2.0;
                return (1.0 / (UNITY_PI * a2)) * pow(max(NdotH, 0.0001), ns);
            }

            float D_select(float NdotH, float roughness)
            {
                if (_DMethod == 1) return D_Beckmann(NdotH, roughness);
                if (_DMethod == 2) return D_GGX(NdotH, roughness);
                return D_Blinn(NdotH, roughness);
            }

            float G1_SchlickGGX(float NdotX, float roughness)
            {
                float a = roughness * roughness;
                float k = a / 2.0;
                return NdotX / (NdotX * (1.0 - k) + k);
            }

            float G_SmithGGX(float NdotL, float NdotV, float roughness)
            {
                return G1_SchlickGGX(NdotL, roughness) * G1_SchlickGGX(NdotV, roughness);
            }

            float G1_Beckmann(float NdotX, float roughness)
            {
                float a = roughness * roughness;
                float NdotX2 = NdotX * NdotX;
                float tanTheta = sqrt(max(0.0, 1.0 - NdotX2)) / max(NdotX, 0.0001);
                float c = 1.0 / (a * tanTheta + 0.0001);
                if (c >= 1.6) return 1.0;
                return (3.535 * c + 2.181 * c * c) / (1.0 + 2.276 * c + 2.577 * c * c);
            }

            float G_SmithBeckmann(float NdotL, float NdotV, float roughness)
            {
                return G1_Beckmann(NdotL, roughness) * G1_Beckmann(NdotV, roughness);
            }

            float G_select(float NdotL, float NdotV, float roughness)
            {
                if (_GMethod == 1) return G_SmithBeckmann(NdotL, NdotV, roughness);
                return G_SmithGGX(NdotL, NdotV, roughness);
            }

            void AccumulateCT(
                float3 N, float3 V, float3 L,
                float3 lightColor,
                float3 Kd, float3 F0, float roughness,
                inout float3 totalDiffuse, inout float3 totalSpecular)
            {
                float3 H = normalize(L + V);
                float NdotL = max(0.0, dot(N, L));
                float NdotV = max(0.0, dot(N, V));
                float NdotH = max(0.0, dot(N, H));
                float VdotH = max(0.0, dot(V, H));

                if (NdotL <= 0.0) return;

                float3 F = F_Schlick(F0, VdotH);
                float3 kdEnergy = 1.0 - F;
                
                totalDiffuse += kdEnergy * (Kd / UNITY_PI) * lightColor * NdotL;

                float  D = D_select(NdotH, roughness);
                float  G = G_select(NdotL, NdotV, roughness);
                float  denom = 4.0 * max(NdotL * NdotV, 0.001);
                totalSpecular += (F * D * G / denom) * lightColor * NdotL;
            }

            // --------------------- Vertex Shader ---------------------
            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position   = UnityObjectToClipPos(v.position);
                output.position_w = mul(unity_ObjectToWorld, v.position);
                output.normal_w   = UnityObjectToWorldNormal(v.normal);
                output.uv         = v.uv;
                return output;
            }

            // --------------------- Fragment Shader ---------------------
            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float2 uv = f.uv * _WoolScale;

                // Generar color procedural de lana
                float W = woolFBM(uv);
                float Z = fuzzNoise(f.uv);
                float3 woolColor = lerp(_Color1.rgb, _Color2.rgb, W);
                woolColor = lerp(woolColor, _Color1.rgb * 1.15, Z * _FuzzStrength);
                woolColor = saturate(woolColor);

                float3 albedo = woolColor * _MaterialKd.rgb;
                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float roughness = max(_Roughness, 0.0001);

                float3 totalDiffuse  = float3(0,0,0);
                float3 totalSpecular = float3(0,0,0);
                float3 L, lightColor;

                GetDirLight(L, lightColor);
                AccumulateCT(N, V, L, lightColor, albedo, _F0.rgb, roughness,
                             totalDiffuse, totalSpecular);

                GetPointLight(f.position_w.xyz, L, lightColor);
                AccumulateCT(N, V, L, lightColor, albedo, _F0.rgb, roughness,
                             totalDiffuse, totalSpecular);

                GetSpotLight(f.position_w.xyz, L, lightColor);
                AccumulateCT(N, V, L, lightColor, albedo, _F0.rgb, roughness,
                             totalDiffuse, totalSpecular);

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * woolColor;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}