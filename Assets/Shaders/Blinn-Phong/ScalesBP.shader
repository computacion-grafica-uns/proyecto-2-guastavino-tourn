Shader "Custom/ScalesBP"
{
    Properties
    {
        _LightIntensity  ("Light Intensity",        Color)  = (1,1,1,1)
        _LightPosition_w ("Light Position (World)", Vector) = (0,5,0,1)
        _AmbientLight    ("Ambient Light",          Color)  = (0.1,0.1,0.1,1)
        _MaterialKa      ("Material Ka",            Vector) = (0.2,0.2,0.2,0)
        _MaterialKs      ("Material Ks",            Vector) = (1,1,1,0)
        _Material_n      ("Material n (brillo)",    Float)  = 32
        _Scale1          ("Color escama 1",         Color)  = (0.0, 0.5, 0.2, 1)
        _Scale2          ("Color escama 2",         Color)  = (0.0, 0.3, 0.1, 1)
        _CellScale       ("Tamaño de celdas",       Float)  = 8.0
        _BumpStrength    ("Fuerza del relieve",     Float)  = 1.0
        _Octaves         ("Octavas del fractal",    Range(1,6)) = 4
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

            float4 _LightIntensity;
            float4 _LightPosition_w;
            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _MaterialKs;
            float  _Material_n;
            float4 _Scale1;
            float4 _Scale2;
            float  _CellScale;
            float  _BumpStrength;
            int    _Octaves;

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

            // ── Worley Noise ──────────────────────────────────────────
            float2 randomPoint(float2 cell)
            {
                cell = float2(
                    dot(cell, float2(127.1, 311.7)),
                    dot(cell, float2(269.5, 183.3))
                );
                return frac(sin(cell) * 43758.5453);
            }

            float2 worley(float2 uv)
            {
                float2 cell  = floor(uv);
                float2 local = frac(uv);

                float F1 = 8.0;
                float F2 = 8.0;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 rndPoint = randomPoint(cell + neighbor);

                        float2 diff = neighbor + rndPoint - local;
                        float  dist = length(diff);

                        if (dist < F1)
                        {
                            F2 = F1;
                            F1 = dist;
                        }
                        else if (dist < F2)
                        {
                            F2 = dist;
                        }
                    }
                }

                return float2(F1, F2);
            }

            // ── Worley fBm ────────────────────────────────────────────
            // Suma varias octavas de worley noise
            // cada octava tiene el doble de frecuencia y la mitad de amplitud
            float worleyFBM(float2 uv)
            {
                float value     = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;

                for (int o = 0; o < _Octaves; o++)
                {
                    value     += amplitude * worley(uv * frequency).x;
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }

                return value;
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
                float2 uv = f.uv * _CellScale;

                // Usamos fBm en lugar de worley simple
                float F1 = worleyFBM(uv);

                // ── Color de la escama ────────────────────────────────
                float3 scaleColor = lerp(_Scale1.rgb, _Scale2.rgb, F1);

                // ── Normal perturbada con gradiente del fBm ───────────
                float eps  = 0.01;
                float F1_dx = worleyFBM(uv + float2(eps, 0)) - F1;
                float F1_dy = worleyFBM(uv + float2(0, eps)) - F1;

                float3 N = normalize(f.normal_w);
                float3 T = normalize(cross(N, float3(0,1,0)));
                float3 B = normalize(cross(N, T));

                float3 perturbedN = normalize(
                    N + _BumpStrength * (F1_dx * T + F1_dy * B)
                );

                // ── Blinn-Phong ───────────────────────────────────────
                float3 L = normalize(_LightPosition_w.xyz - f.position_w.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);
                float3 H = (L + V) / 2.0;

                float3 ambient  = _MaterialKa.rgb * _AmbientLight.rgb;

                float3 diffuse  = scaleColor * _LightIntensity.rgb
                                  * max(0.0, dot(perturbedN, L));

                float3 specular = _MaterialKs.rgb * _LightIntensity.rgb
                                  * pow(max(0.0, dot(perturbedN, H)), _Material_n);

                fixed4 fragColor;
                fragColor.rgb = ambient + diffuse + specular;
                fragColor.a   = 1.0;
                return fragColor;
            }

            ENDCG
        }
    }
}