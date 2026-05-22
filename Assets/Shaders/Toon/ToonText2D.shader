Shader "toonText2D"
{
    Properties
    {
        _MainTex         ("Textura 2D",             2D)          = "white" {}
        _AmbientLight    ("Ambient Light",           Color)  = (1,1,1,1)
        _MaterialKa      ("Material Ka",             Vector) = (0,0,0,0)
        _MaterialKd      ("Material Kd",             Vector) = (0,0,0,0)
        _MaterialKs      ("Material Ks",             Vector) = (1,1,1,0)
        _Material_n      ("Material n (brillo)",     Float)  = 32
        _Bands           ("Toon Bands",             Range(1,8)) = 3
        _Alpha           ("Alpha (transparencia)",  Range(0,1)) = 1.0
        [Toggle] _ZWrite ("ZWrite (opaco=1)",       Float)       = 1
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        ZWrite [_ZWrite]
        Blend SrcAlpha OneMinusSrcAlpha

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
            float4 _MaterialKs;
            float  _Material_n;
            float  _Bands;
            float  _Alpha;

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

            float toonStep(float value, float bands)
            {
                if (bands <= 1.0) return value;
                return clamp(floor(value * bands) / (bands - 1.0), 0.0, 1.0);
            }

            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position   = UnityObjectToClipPos(v.position);
                output.position_w = mul(unity_ObjectToWorld, v.position);
                output.normal_w   = UnityObjectToWorldNormal(v.normal);
                output.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return output;
            }

            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float3 texColor = tex2D(_MainTex, f.uv).rgb;
                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);

                float3 totalDiffuse = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                float3 L, lightColor;
                float bands = max(1.0, _Bands);

                GetDirLight(L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * _MaterialKd.rgb * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                GetPointLight(f.position_w.xyz, L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * _MaterialKd.rgb * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                GetSpotLight(f.position_w.xyz, L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * _MaterialKd.rgb * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * texColor;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = _Alpha;
                return fragColor;
            }

            ENDCG
        }
    }
}