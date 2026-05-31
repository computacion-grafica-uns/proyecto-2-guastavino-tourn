Shader "Custom/BlinnPhong/BPNormalMap"
{
    Properties
    {
        // ── Albedo: 0 = color, 1 = textura ───────────────────────
        [IntRange] _AlbedoMode  ("Albedo: 0=Color  1=Texture", Range(0,1)) = 0
        _BaseColor       ("Color base",             Color)      = (1,1,1,1)
        _MainTex         ("Textura albedo",          2D)         = "white" {}

        // ── Normal Map ────────────────────────────────────────────
        _NormalMap       ("Normal Map",             2D)         = "bump" {}
        _NormalStrength  ("Intensidad del normal",  Range(0,3)) = 1.0

        // ── Iluminación ───────────────────────────────────────────
        _AmbientLight    ("Ambient Light",          Color)      = (0.2,0.2,0.2,1)
        _MaterialKa      ("Material Ka",            Vector)     = (0.2,0.2,0.2,0)
        _MaterialKs      ("Material Ks",            Vector)     = (0.5,0.5,0.5,0)
        _Material_n      ("Material n (brillo)",    Float)      = 32
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

            int       _AlbedoMode;
            float4    _BaseColor;
            sampler2D _MainTex;
            float4    _MainTex_ST;
            sampler2D _NormalMap;
            float4    _NormalMap_ST;
            float     _NormalStrength;
            float4    _AmbientLight;
            float4    _MaterialKa;
            float4    _MaterialKs;
            float     _Material_n;

            struct vertexData
            {
                float4 position : POSITION;
                float3 normal   : NORMAL;
                float2 uv       : TEXCOORD0;
                float4 tangent  : TANGENT;
            };

            struct v2f
            {
                float4 position     : SV_POSITION;
                float4 position_w   : TEXCOORD0;
                float2 uv_MainTex   : TEXCOORD1;
                float2 uv_NormalMap : TEXCOORD2;
                float3 T_w          : TEXCOORD3;
                float3 B_w          : TEXCOORD4;
                float3 N_w          : TEXCOORD5;
            };

            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position     = UnityObjectToClipPos(v.position);
                output.position_w   = mul(unity_ObjectToWorld, v.position);
                output.uv_MainTex   = TRANSFORM_TEX(v.uv, _MainTex);
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
                // ── Albedo ────────────────────────────────────────
                float3 albedo;
                if (_AlbedoMode == 1)
                    albedo = tex2D(_MainTex, f.uv_MainTex).rgb;
                else
                    albedo = _BaseColor.rgb;

                // ── Normal Map ────────────────────────────────────
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

                // ── Iluminación Blinn-Phong ───────────────────────
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 totalDiffuse  = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);
                float3 L, lightColor;
                LightResult r;

                GetDirLight(L, lightColor);
                r = BlinnPhongLight(N_world, V, L, lightColor, albedo, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                GetPointLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N_world, V, L, lightColor, albedo, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                GetSpotLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N_world, V, L, lightColor, albedo, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * albedo;

                fixed4 fragColor;
                fragColor.rgb = ambient + max(totalDiffuse, 0) + max(totalSpecular, 0);
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}
