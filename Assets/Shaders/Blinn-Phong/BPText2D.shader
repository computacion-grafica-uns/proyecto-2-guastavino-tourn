Shader "Custom/BPText2D"
{
    Properties
    {
        _MainTex         ("Textura 2D",             2D)          = "white" {}
        _LightIntensity  ("Light Intensity",         Color)  = (1,1,1,1)
        _LightPosition_w ("Light Position (World)",  Vector) = (0,5,0,1)
        _AmbientLight    ("Ambient Light",           Color)  = (1,1,1,1)
        _MaterialKa      ("Material Ka",             Vector) = (0.2,0.2,0.2,0)
        _MaterialKd      ("Material Kd",             Vector) = (0.6,0.6,0.6,0)
        _MaterialKs      ("Material Ks",             Vector) = (1,1,1,0)
        _Material_n      ("Material n (brillo)",     Float)  = 32
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

            sampler2D _MainTex;
            float4    _MainTex_ST;  
            float4 _LightIntensity;
            float4 _LightPosition_w;
            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _MaterialKd;
            float4 _MaterialKs;
            float  _Material_n;

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
                output.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return output;
            }

            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float3 texColor = tex2D(_MainTex, f.uv).rgb;
                float3 N = normalize(f.normal_w);
                float3 L = normalize(_LightPosition_w.xyz - f.position_w.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 H = normalize(L + V);

                float3 ambient = _MaterialKa.rgb * _AmbientLight.rgb * texColor;
                
                float3 diffuse = texColor * _MaterialKd.rgb * _LightIntensity.rgb * max(0.0, dot(N, L));

                float3 specular = _MaterialKs.rgb * _LightIntensity.rgb * pow(max(0.0, dot(N, H)), _Material_n);

                fixed4 fragColor;
                fragColor.rgb = ambient + diffuse + specular;
                fragColor.a   = 1.0;
                return fragColor;
            }

            ENDCG
        }
    }
}