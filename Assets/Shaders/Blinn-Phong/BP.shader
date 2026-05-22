Shader "Custom/BP"
{
    Properties
    {
        _LightIntensity  ("Light Intensity",         Color)  = (1,1,1,1)
        _LightPosition_w ("Light Position (World)",  Vector) = (0,5,0,1)
        _AmbientLight    ("Ambient Light",           Color)  = (1,1,1,1)
        _MaterialKa      ("Material Ka",             Vector) = (0.2,0.2,0.2,0)
        _MaterialKd      ("Material Kd",             Vector) = (0.6,0.6,0.6,0)
        _MaterialKs      ("Material Ks",             Vector) = (1,1,1,0)
        _Material_n      ("Material n (brillo)",     Float)  = 32
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

            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _MaterialKd;
            float4 _MaterialKs;
            float  _Material_n;
            float  _Alpha;

            struct vertexData
            {
                float4 position : POSITION;
                float3 normal   : NORMAL;
            };

            struct v2f
            {
                float4 position   : SV_POSITION;
                float4 position_w : TEXCOORD0;
                float3 normal_w   : TEXCOORD1;
            };

            v2f vertexShader(vertexData v)
            {
                v2f output;
                output.position   = UnityObjectToClipPos(v.position);
                output.position_w = mul(unity_ObjectToWorld, v.position);
                output.normal_w   = UnityObjectToWorldNormal(v.normal);
                return output;
            }

            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);

                float3 totalDiffuse  = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                float3 L, lightColor;
                LightResult r;

                GetDirLight(L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, _MaterialKd.rgb, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                GetPointLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, _MaterialKd.rgb, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                GetSpotLight(f.position_w.xyz, L, lightColor);
                r = BlinnPhongLight(N, V, L, lightColor, _MaterialKd.rgb, _MaterialKs.rgb, _Material_n);
                totalDiffuse  += r.diffuse;
                totalSpecular += r.specular;

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb;

                fixed4 fragColor;
                fragColor.rgb = ambient + totalDiffuse + totalSpecular;
                fragColor.a   = _Alpha;
                return fragColor;
            }

            ENDCG
        }
    }
}