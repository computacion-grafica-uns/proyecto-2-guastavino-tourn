Shader "Custom/Toon/BlueWillowToon"
{
    Properties
    {
        // ── Iluminación Toon ─────────────────────────────────────────
        _AmbientLight    ("Ambient Light",           Color)  = (1,1,1,1)
        _MaterialKa      ("Material Ka",             Vector) = (0,0,0,0)
        _MaterialKs      ("Material Ks",             Vector) = (1,1,1,0)
        _Material_n      ("Material n (brillo)",     Float)  = 32
        _Bands           ("Toon Bands",             Range(1,8)) = 3
        _OutlineColor    ("Outline Color",          Color)      = (0,0,0,1)
        _OutlineWidth    ("Outline Width",          Range(0, 10)) = 0.5
        _Alpha           ("Alpha (transparencia)",  Range(0,1)) = 1.0

        // ── Paleta Blue Willow ───────────────────────────────────────
        _ColorBase      ("Porcelana base",       Color)  = (0.96, 0.96, 0.98, 1)
        _ColorDark      ("Azul oscuro",          Color)  = (0.10, 0.23, 0.54, 1)
        _ColorMid       ("Azul medio",           Color)  = (0.18, 0.40, 0.76, 1)
        _ColorLight     ("Azul claro",           Color)  = (0.45, 0.65, 0.90, 1)

        // ── Layout Blue Willow ───────────────────────────────────────
        _GridCount      ("Flores por fila",      Range(1,30))      = 8
        _PeonyRadius    ("Radio peonía",         Range(0.05,3))    = 0.13
        _SmallRadius    ("Radio flor pequeña",   Range(0.02,3))    = 0.045
        _SmallOffset    ("Offset flor pequeña",  Range(0.0, 1.0))  = 0.4
        _Jitter         ("Jitter de posición",   Range(0,4))       = 0.08

        // ── Bandas Blue Willow ───────────────────────────────────────
        _BandTopY       ("Banda superior Y",     Range(0, 1.0))    = 0.15
        _BandTopH       ("Banda superior Alto",  Range(0.01, 0.5)) = 0.08
        _BandBotY       ("Banda inferior Y",     Range(0, 1.0))    = 0.75
        _BandBotH       ("Banda inferior Alto",  Range(0.01, 0.5)) = 0.25

        [Toggle] _ZWrite ("ZWrite (opaco=1)",       Float)       = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" } // Cambiado a Geometry/Opaque para la porcelana

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
            Cull Back 
            CGPROGRAM
            #pragma vertex vertexShader
            #pragma fragment fragmentShader
            #include "UnityCG.cginc"
            #include "../LightingGlobals.cginc"
            #include "../BlueWillowPattern.cginc" // Importamos el patrón base

            float4 _AmbientLight;
            float4 _MaterialKa;
            float4 _MaterialKs;
            float  _Material_n;
            float  _Bands;
            float  _Alpha;

            struct vertexData
            {
                float4 position : POSITION;
                float3 normal   : NORMAL;
                float2 uv       : TEXCOORD0; // Necesario para el patrón
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
                output.normal_w   = UnityObjectToWorldNormal(v.normal);
                output.uv         = v.uv; 
                return output;
            }

            fixed4 fragmentShader(v2f f) : SV_Target
            {
                float3 N = normalize(f.normal_w);
                float3 V = normalize(_WorldSpaceCameraPos - f.position_w.xyz);

                // Reemplazamos _MaterialKd con nuestro color Blue Willow generado dinámicamente
                float3 texColor = getBlueWillowPattern(f.uv);

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
                    totalDiffuse += texColor * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                GetPointLight(f.position_w.xyz, L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * lightColor * toonNdotL;
                    totalSpecular += _MaterialKs.rgb * lightColor * toonSpec;
                }

                GetSpotLight(f.position_w.xyz, L, lightColor);
                {
                    float3 H = normalize(L + V);
                    float NdotL = max(0.0, dot(N, L));
                    float toonNdotL = toonStep(NdotL, bands);
                    float specBase = pow(max(0.0, dot(N, H)), _Material_n);
                    float toonSpec = toonStep(specBase, bands);
                    totalDiffuse += texColor * lightColor * toonNdotL;
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