Shader "Custom/CookTorrence/CTNormalMap"
{
    Properties
    {
        _BaseColor       ("Color base",             Color)       = (1,1,1,1)
        _NormalMap       ("Normal Map",             2D)          = "bump" {}
        _NormalStrength  ("Intensidad del normal",  Range(0,3))  = 1.0
        _AmbientLight    ("Ambient Light",          Color)       = (0.2,0.2,0.2,1)
        _MaterialKa      ("Material Ka (ambiente)", Vector)      = (0.2,0.2,0.2,0)
        _MaterialKd      ("Material Kd (difuso)",   Vector)      = (0.6,0.6,0.6,0)
        _F0              ("F0 (reflectancia base)", Color)       = (0.04,0.04,0.04,1)
        _Roughness       ("Roughness",              Range(0,1))  = 0.5

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

            float4 _BaseColor;
            sampler2D _NormalMap;
            float4    _NormalMap_ST;
            float     _NormalStrength;
            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _MaterialKd;
            float4 _F0;
            float  _Roughness;
            int    _DMethod;
            int    _GMethod;

            struct vertexData
            {
                float4 position : POSITION;
                float3 normal   : NORMAL;
                float2 uv       : TEXCOORD0;
                float4 tangent  : TANGENT;
            };

            struct v2f
            {
                float4 position   : SV_POSITION;
                float4 position_w : TEXCOORD0;
                float2 uv_NormalMap : TEXCOORD2;
                float3 T_w        : TEXCOORD3;
                float3 B_w        : TEXCOORD4;
                float3 N_w        : TEXCOORD5;
            };

            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position   = UnityObjectToClipPos(v.position);
                output.position_w = mul(unity_ObjectToWorld, v.position);
                output.uv_NormalMap = TRANSFORM_TEX(v.uv, _NormalMap);

                float3 N = UnityObjectToWorldNormal(v.normal);
                float3 T = UnityObjectToWorldDir(v.tangent.xyz);
                float3 B = cross(N, T) * v.tangent.w;

                output.N_w = N;
                output.T_w = T;
                output.B_w = B;

                return output;
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

                totalDiffuse += (Kd / UNITY_PI) * lightColor * NdotL;

                float3 F = F_Schlick(F0, VdotH);
                float  D = D_select(NdotH, roughness);
                float  G = G_select(NdotL, NdotV, roughness);
                float  denom = 4.0 * max(NdotL * NdotV, 0.001);
                totalSpecular += (F * D * G / denom) * lightColor * NdotL;
            }

            // --------------------- Fragment Shader ---------------------
            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float3 normalTS = UnpackNormal(tex2D(_NormalMap, f.uv_NormalMap));
                normalTS.xy *= _NormalStrength;
                normalTS = normalize(normalTS);

                float3 T = normalize(f.T_w);
                float3 B = normalize(f.B_w);
                float3 N = normalize(f.N_w);
                T = normalize(T - N * dot(T, N));
                B = cross(N, T);

                float3 N_world = normalize(
                    normalTS.x * T +
                    normalTS.y * B +
                    normalTS.z * N
                );

                float3 albedo = _BaseColor.rgb * _MaterialKd.rgb;
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float roughness = max(_Roughness, 0.0001);

                float3 totalDiffuse  = float3(0,0,0);
                float3 totalSpecular = float3(0,0,0);
                float3 L, lightColor;

                GetDirLight(L, lightColor);
                AccumulateCT(N_world, V, L, lightColor, albedo, _F0.rgb, roughness,
                             totalDiffuse, totalSpecular);

                GetPointLight(f.position_w.xyz, L, lightColor);
                AccumulateCT(N_world, V, L, lightColor, albedo, _F0.rgb, roughness,
                             totalDiffuse, totalSpecular);

                GetSpotLight(f.position_w.xyz, L, lightColor);
                AccumulateCT(N_world, V, L, lightColor, albedo, _F0.rgb, roughness,
                             totalDiffuse, totalSpecular);

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * _BaseColor.rgb;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}