Shader "Custom/Toon/ToonNormalMap"
{
    Properties
    {
        _BaseColor       ("Color base",              Color)  = (1,1,1,1)
        _NormalMap       ("Normal Map",             2D)     = "bump" {}
        _NormalStrength  ("Intensidad del normal",  Range(0,3)) = 1.0
        _AmbientLight    ("Ambient Light",          Color)  = (0.2,0.2,0.2,1)
        _MaterialKa      ("Material Ka",            Range(0,1)) = 0.2
        _MaterialKs      ("Material Ks",            Vector) = (0.5,0.5,0.5,0)
        _Material_n      ("Material n (brillo)",    Float)  = 32
        _Bands           ("Toon Bands",             Range(1,8)) = 3
        _OutlineColor    ("Outline Color",          Color)      = (0,0,0,1)
        _OutlineWidth    ("Outline Width",          Range(0, 10)) = 0.5
        [Toggle] _ZWrite ("ZWrite (opaco=1)",       Float)       = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque"}

        ZWrite [_ZWrite]
        Blend SrcAlpha OneMinusSrcAlpha

        // --- OUTLINE PASS (Inverted Hull) ---
        Pass
        {
            Name "OUTLINE"
            Cull Front // Renderizamos solo las caras traseras
            ZWrite On

            CGPROGRAM
            #pragma vertex vertOutline
            #pragma fragment fragOutline
            #include "UnityCG.cginc"

            float _OutlineWidth;
            float4 _OutlineColor;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vertOutline(appdata v)
            {
                v2f o;
                // Inflar los vértices a lo largo de sus normales antes de transformar
                v.vertex.xyz += v.normal * _OutlineWidth;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 fragOutline(v2f i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDCG
        }

        // --- MAIN GEOMETRY PASS ---
        Pass
        {
            CGPROGRAM
            #pragma vertex vertexShader
            #pragma fragment fragmentShader
            #include "UnityCG.cginc"
            #include "../LightingGlobals.cginc"

            float4 _BaseColor;
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float  _NormalStrength;
            float4 _AmbientLight;
            float  _MaterialKa;
            float4 _MaterialKs;
            float  _Material_n;
            float  _Bands;

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

            float toonStep(float value, float bands)
            {
                if (bands <= 1.0)
                {
                    return value;
                }

                return floor(value * bands) / (bands - 1.0);
            }

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

                float3 texColor = _BaseColor.rgb;
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);

                float3 totalDiffuse = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                float3 L, lightColor;
                float bands = max(1.0, _Bands);

                GetDirLight(L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N_world, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N_world, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                GetPointLight(f.position_w.xyz, L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N_world, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N_world, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                GetSpotLight(f.position_w.xyz, L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N_world, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N_world, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                float3 ambient = _MaterialKa * _AmbientLight.rgb * texColor;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = 1.0;
                return fragColor;
            }

            ENDCG
        }
    }
}