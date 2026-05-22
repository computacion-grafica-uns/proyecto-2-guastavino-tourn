#ifndef LIGHTING_GLOBALS_INCLUDED
#define LIGHTING_GLOBALS_INCLUDED

// ── Variables globales seteadas por LightManager ─────────────────
float4 _DirLightDir;
float4 _DirLightColor;

float4 _PointLightPos;
float4 _PointLightColor;

float4 _SpotLightPos;
float4 _SpotLightDir;
float4 _SpotLightColor;
float _SpotLightCosAngle;
float _PointLightRange;
float _SpotLightRange;
float _SpotLightCosInner;

// ── Estructura de resultado ───────────────────────────────────────
struct LightResult
{
    float3 diffuse;
    float3 specular;
};

// ── Blinn-Phong para una luz ──────────────────────────────────────
LightResult BlinnPhongLight(
    float3 N, float3 V, float3 L,
    float3 lightColor,
    float3 Kd, float3 Ks, float shininess)
{
    LightResult r;
    float3 H = normalize(L + V);
    float NdotL = max(0.0, dot(N, L));
    float NdotH = max(0.0, dot(N, H));

    r.diffuse = Kd * lightColor * NdotL;

    // si shininess es 0 no hay especular
    float spec = (shininess > 0.0) ? pow(NdotH, shininess) : 0.0;
    r.specular = Ks * lightColor * spec;

    return r;
}

// ── Cook-Torrance para una luz ────────────────────────────────────
// (requiere F, D, G ya calculados afuera — se pasa NdotL y el color)
float3 CookTorranceDiffuse(float3 Kd, float3 lightColor, float NdotL)
{
    return (Kd / UNITY_PI) * lightColor * NdotL;
}

float3 CookTorranceSpecular(float3 F, float D, float G,
    float NdotL, float NdotV, float3 lightColor)
{
    float denom = 4.0 * max(NdotL * NdotV, 0.001);
    return (F * D * G / denom) * lightColor;
}

// ── Obtener L y color para cada tipo de luz ───────────────────────

// Direccional: L es la dirección opuesta al forward de la luz
void GetDirLight(out float3 L, out float3 color)
{
    L = normalize(-_DirLightDir.xyz);
    color = _DirLightColor.rgb;
}

float DistanceAttenuation(float dist, float range)
{
    float t = saturate(1.0 - dist / range);
    return t * t; // falloff cuadrático suave hasta el range
}

// Point: L apunta del fragmento hacia la luz
void GetPointLight(float3 worldPos, out float3 L, out float3 color)
{
    float3 toLight = _PointLightPos.xyz - worldPos;
    float dist = length(toLight);
    L = toLight / max(dist, 1e-4);
    color = _PointLightColor.rgb * DistanceAttenuation(dist, _PointLightRange);
}

void GetSpotLight(float3 worldPos, out float3 L, out float3 color)
{
    float3 toLight = _SpotLightPos.xyz - worldPos;
    float dist = length(toLight);
    L = toLight / max(dist, 1e-4);

    float3 spotDir = normalize(_SpotLightDir.xyz);
    float cosA = dot(-L, spotDir); // -L = dir luz→fragmento
    float cone = smoothstep(_SpotLightCosAngle, // borde externo (0)
                                _SpotLightCosInner, // borde interno (1)
                                cosA);

    float att = DistanceAttenuation(dist, _SpotLightRange) * cone;
    color = _SpotLightColor.rgb * att;
}



#endif