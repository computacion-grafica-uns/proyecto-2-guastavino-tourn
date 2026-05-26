Shader "Custom/CTText2D"
{
    Properties
    {
        _MainTex         ("Textura 2D",              2D)          = "white" {}
        _AmbientLight    ("Ambient Light",           Color)       = (0.2,0.2,0.2,1)
        _MaterialKa      ("Material Ka (ambiente)",  Vector)      = (0.2,0.2,0.2,0)
        _MaterialKd      ("Material Kd (difuso)",    Vector)      = (0.6,0.6,0.6,0)
        _F0              ("F0 (reflectancia base)",  Color)       = (0.04,0.04,0.04,1)
        _Roughness       ("Roughness",               Range(0,1))  = 0.5

        [Space]
        [Header(Metodos)]
        // 0 = Blinn       | 1 = Beckmann    | 2 = GGX
        [IntRange] _DMethod ("D: 0=Blinn  1=Beckmann  2=GGX", Range(0,2)) = 0
        // 0 = Smith-GGX | 1 = Smith-Beckmann
        [IntRange] _GMethod ("G: 0=SmithGGX  1=SmithBeckmann ", Range(0,1)) = 0
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

            sampler2D _MainTex;
            float4    _MainTex_ST;

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
            };

            struct v2f
            {
                float4 position   : SV_POSITION;
                float4 position_w : TEXCOORD0;
                float3 normal_w   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
            };

            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position   = UnityObjectToClipPos(v.position);
                output.position_w = mul(unity_ObjectToWorld, v.position);
                output.normal_w   = UnityObjectToWorldNormal(v.normal);
                output.uv         = TRANSFORM_TEX(v.uv, _MainTex);
                return output;
            }

            // --------------------- Funciones Cook-Torrance ---------------------
            // Schlick 1994
            float3 F_Schlick(float3 F0, float VdotH)
            {
                return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
            }

            // GGX
            float D_GGX(float NdotH, float roughness)
            {
                float a  = roughness * roughness;
                float a2 = a * a;
                float d  = (NdotH * NdotH * (a2 - 1.0) + 1.0);
                return a2 / (UNITY_PI * d * d);
            }

            // Beckmann
            float D_Beckmann(float NdotH, float roughness)
            {
                float a2     = max(roughness * roughness * roughness * roughness, 0.00001);
                float NdotH2 = max(NdotH * NdotH, 0.00001);
                float exponent = (NdotH2 - 1.0) / (a2 * NdotH2);
                return exp(exponent) / (UNITY_PI * a2 * NdotH2 * NdotH2);
            }

            // Blinn
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

            // Smith-Schlick-GGX
            float G1_SchlickGGX(float NdotX, float roughness)
            {
                float a = roughness * roughness;
                float k = a / 2.0;
                return NdotX / (NdotX * (1.0 - k) + k);
            }

            float G_SmithGGX(float NdotL, float NdotV, float roughness)
            {
                return G1_SchlickGGX(NdotL, roughness)
                     * G1_SchlickGGX(NdotV, roughness);
            }

            // Smith-Beckmann
            float G1_Beckmann(float NdotX, float roughness)
            {
                float a = roughness * roughness;
                float NdotX2 = NdotX * NdotX;
                float tanTheta = sqrt(max(0.0, 1.0 - NdotX2)) / max(NdotX, 0.0001);
                float c = 1.0 / (a * tanTheta + 0.0001);

                if (c >= 1.6)
                    return 1.0;

                return (3.535 * c + 2.181 * c * c)
                     / (1.0 + 2.276 * c + 2.577 * c * c);
            }

            float G_SmithBeckmann(float NdotL, float NdotV, float roughness)
            {
                return G1_Beckmann(NdotL, roughness)
                     * G1_Beckmann(NdotV, roughness);
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
                // Muestreo de la textura principal
                float3 texColor = tex2D(_MainTex, f.uv).rgb;
                float3 albedo = texColor * _MaterialKd.rgb;

                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float roughness = max(_Roughness, 0.0001);

                float3 totalDiffuse  = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);
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

                // Componente ambiental: Ka * luz ambiental * textura (igual que en Blinn-Phong)
                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * texColor;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}