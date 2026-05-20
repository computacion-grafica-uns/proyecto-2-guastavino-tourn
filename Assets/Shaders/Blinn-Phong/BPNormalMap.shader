Shader "Custom/BPNormalMap"
{
    Properties
    {
        _BaseColor ("Color base", Color) = (1, 1, 1, 1)
        _NormalMap       ("Normal Map",             2D)         = "bump" {}
        _NormalStrength  ("Intensidad del normal",  Range(0,3)) = 1.0
        _LightIntensity  ("Light Intensity",        Color)      = (1,1,1,1)
        _LightPosition_w ("Light Position (World)", Vector)     = (0,5,0,1)
        _AmbientLight    ("Ambient Light",          Color)      = (0.2,0.2,0.2,1)
        _MaterialKa      ("Material Ka",            Range(0,1)) = 0.2
        _MaterialKs      ("Material Ks",            Vector)     = (0.5,0.5,0.5,0)
        _Material_n      ("Material n (brillo)",    Float)      = 32
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"}

        Pass
        {
            CGPROGRAM
            #pragma vertex vertexShader
            #pragma fragment fragmentShader
            #include "UnityCG.cginc"
 
            float4 _BaseColor;
            sampler2D _NormalMap;
            float4    _NormalMap_ST;
            float     _NormalStrength;
            float4    _LightIntensity;
            float4    _LightPosition_w;
            float4    _AmbientLight;
            float     _MaterialKa;
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
                float4 position   : SV_POSITION;
                float4 position_w : TEXCOORD0;
                // Pasamos los 3 vectores de la matriz TBN al fragmento
                // en world space, uno por cada TEXCOORD
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

                // ── Construir TBN en world space ──────────────────────
                // N: normal del vértice pasada a world space
                float3 N = UnityObjectToWorldNormal(v.normal);

                // T: tangente del vértice pasada a world space
                // v.tangent.xyz es la dirección, v.tangent.w es el signo de B
                float3 T = UnityObjectToWorldDir(v.tangent.xyz);

                // B: bitangente = cross(N, T) * signo
                // El signo (v.tangent.w) corrige el handedness del espacio tangente
                // dependiendo de cómo el artista hizo el UV unwrap
                float3 B = cross(N, T) * v.tangent.w;

                output.N_w = N;
                output.T_w = T;
                output.B_w = B;

                return output;
            }

            fixed4 fragmentShader(v2f f) : SV_Target
            {
                // ── Leer y decodificar el normal map ──────────────────
                // tex2D devuelve valores en [0, 1]
                // UnpackNormal los convierte a [-1, 1] y maneja la compresión
                // que Unity aplica automáticamente a las texturas de tipo Normal Map
                float3 normalTS = UnpackNormal(tex2D(_NormalMap, f.uv_NormalMap));

                // _NormalStrength escala XY para controlar la intensidad del efecto
                // Z se recalcula para mantener el vector normalizado
                normalTS.xy *= _NormalStrength;
                normalTS = normalize(normalTS);

                // ── Convertir de Tangent Space a World Space ──────────
                // Reconstruimos y normalizamos los vectores TBN
                // (la interpolación entre vértices los puede desortogonalizar)
                float3 T = normalize(f.T_w);
                float3 B = normalize(f.B_w);
                float3 N = normalize(f.N_w);

                N = normalize(N);
                T = normalize(T - N * dot(T, N));
                B = cross(N, T);

                // Multiplicación TBN × normalTS
                // Cada componente del normal en tangent space pondera
                // uno de los ejes del espacio world local a la superficie
                float3 N_world = normalize(
                    normalTS.x * T +   // componente X → dirección tangente
                    normalTS.y * B +   // componente Y → dirección bitangente
                    normalTS.z * N     // componente Z → dirección normal original
                );

                // ── Color base de la textura difusa ───────────────────
                float3 texColor = _BaseColor.rgb;

                // ── Blinn-Phong con la normal perturbada ──────────────
                float3 L = normalize(_LightPosition_w.xyz - f.position_w.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 H = normalize(L + V);

                float3 ambient  = _MaterialKa * _AmbientLight.rgb * texColor;
                float3 diffuse  = texColor * _LightIntensity.rgb * max(0.0, dot(N_world, L));
                float3 specular = _MaterialKs.rgb * _LightIntensity.rgb
                                  * pow(max(0.0, dot(N_world, H)), _Material_n);

                fixed4 fragColor;
                fragColor.rgb = ambient + diffuse + specular;
                fragColor.a   = 1.0;
                return fragColor;
            }
            ENDCG
        }
    }
}