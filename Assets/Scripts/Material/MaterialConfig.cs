using UnityEngine;

// ============================================================
//  MaterialConfig.cs
//  ScriptableObject que representa la configuración de UN nodo
//  en la jerarquía de tags (ej: "base", "bp", "bp_cuero", etc.)
//
//  Nombres de propiedades alineados con los shaders reales:
//
//  COMÚN (todos los shaders):
//    _AmbientLight  _MaterialKa (float4)  _Alpha
//
//  ALBEDO — dos mecanismos según el shader:
//    _BaseColor    → shaders simples sin textura (BP, CT, TN)
//    _MainTex      → shaders Text2D y NormalMap en modo Texture
//    _AlbedoMode   → int en shaders NormalMap:
//                    0 = usa _BaseColor
//                    1 = usa _MainTex
//
//  NORMAL MAP:
//    _NormalMap  _NormalStrength
//
//  COMPARTIDAS (BP + CT + TN):
//    _MaterialKd
//
//  COMPARTIDAS (BP + TN):
//    _MaterialKs  _Material_n
//
//  COOK-TORRANCE exclusivas:
//    _F0  _Roughness  _DMethod  _GMethod
//
//  TOON exclusivas:
//    _Bands  _OutlineColor  _OutlineWidth
//
//  BLUE WILLOW (procedural):
//    No usa _MainTex ni _BaseColor. No se controla por MaterialManager.
// ============================================================

[CreateAssetMenu(fileName = "MatConfig_", menuName = "MaterialManager/MaterialConfig")]
public class MaterialConfig : ScriptableObject
{
    [Header("Identificación")]
    [Tooltip("Clave del nodo en la jerarquía. Ej: 'base', 'bp', 'bp_cuero', 'bp_cuero_sillas'")]
    public string tagKey = "";

    // --------------------------------------------------------
    //  Propiedades comunes — nivel: base
    // --------------------------------------------------------
    [Header("─── Comunes ───")]

    [Tooltip("_AmbientLight: color de la luz ambiental global")]
    public bool overrideAmbientLight = false;
    public Color ambientLight = new Color(0.2f, 0.2f, 0.2f, 1f);

    [Tooltip("_MaterialKa (float4): coeficiente ambiental del material")]
    public bool overrideKa = false;
    public Color Ka = new Color(0.2f, 0.2f, 0.2f, 0f);

    [Tooltip("_MaterialKd (float4): coeficiente difuso.")]
    public bool overrideKd = false;
    public Color Kd = new Color(0.6f, 0.6f, 0.6f, 0f);

    [Tooltip("_Alpha: transparencia (0=transparente, 1=opaco)")]
    public bool overrideAlpha = false;
    [Range(0f, 1f)] public float alpha = 1f;

    // --------------------------------------------------------
    //  Albedo — shaders con color o textura
    //  NO aplica a shaders BlueWillow (procedurales)
    //
    //  _AlbedoMode solo tiene efecto en shaders NormalMap.
    //  Los shaders Text2D siempre usan _MainTex.
    //  Los shaders simples (BP, CT, TN) siempre usan _BaseColor.
    // --------------------------------------------------------
    [Header("─── Albedo ───")]

    [Tooltip("_AlbedoMode (int): modo albedo para shaders NormalMap\n0 = usa _BaseColor\n1 = usa _MainTex")]
    public bool overrideAlbedoMode = false;
    [Range(0, 1)] public int albedoMode = 0;

    [Tooltip("_BaseColor: color sólido como albedo (modo 0 o shaders simples)")]
    public bool overrideBaseColor = false;
    public Color baseColor = Color.white;

    [Tooltip("_MainTex: textura albedo 2D (shaders Text2D o NormalMap en modo 1)")]
    public bool overrideMainTex = false;
    public Texture2D mainTex;

    [Tooltip("Tiling de _MainTex (escala UV)")]
    public bool overrideTiling = false;
    public Vector2 tiling = Vector2.one;

    [Tooltip("Offset de _MainTex (desplazamiento UV)")]
    public bool overrideOffset = false;
    public Vector2 offset = Vector2.zero;

    // --------------------------------------------------------
    //  Normal Map — shaders NormalMap (BP/CT/TN)
    // --------------------------------------------------------
    [Header("─── Normal Map ───")]

    [Tooltip("_NormalMap: textura de normal map")]
    public bool overrideNormalMap = false;
    public Texture2D normalMap;

    [Tooltip("_NormalStrength: intensidad del normal map (0-3)")]
    public bool overrideNormalStrength = false;
    [Range(0f, 3f)] public float normalStrength = 1f;

    // --------------------------------------------------------
    //  Compartidas BP + TN
    //  _MaterialKs y _Material_n los usan BP y Toon (no CT)
    // --------------------------------------------------------
    [Header("─── Compartidas (BP / TN) ───")]

    [Tooltip("_MaterialKs (float4): coeficiente especular. Lo usan BP y Toon")]
    public bool overrideKs = false;
    public Color Ks = new Color(1f, 1f, 1f, 0f);

    [Tooltip("_Material_n: exponente de brillo especular (1-256). Lo usan BP y Toon")]
    public bool overrideN = false;
    [Range(1f, 256f)] public float materialN = 32f;

    // --------------------------------------------------------
    //  Cook-Torrance exclusivas — nivel: ct
    //  Shaders: CT, CTText2D, CTNormalMap
    // --------------------------------------------------------
    [Header("─── Cook-Torrance ───")]

    [Tooltip("_F0 (Color/float4): reflectancia base (fresnel)")]
    public bool overrideF0 = false;
    public Color F0 = new Color(0.04f, 0.04f, 0.04f, 1f);

    [Tooltip("_Roughness: rugosidad de la superficie (0-1)")]
    public bool overrideRoughness = false;
    [Range(0f, 1f)] public float roughness = 0.5f;

    [Tooltip("_DMethod: distribución NDF (0=Blinn, 1=Beckmann, 2=GGX)")]
    public bool overrideDMethod = false;
    [Range(0, 2)] public int dMethod = 0;

    [Tooltip("_GMethod: geometría G (0=SmithGGX, 1=SmithBeckmann)")]
    public bool overrideGMethod = false;
    [Range(0, 1)] public int gMethod = 0;

    // --------------------------------------------------------
    //  Toon exclusivas — nivel: tn
    //  Shaders: ToonShader, ToonText2D, ToonNormalMap
    // --------------------------------------------------------
    [Header("─── Toon ───")]

    [Tooltip("_Bands: cantidad de bandas de sombra toon (1-8)")]
    public bool overrideBands = false;
    [Range(1f, 8f)] public float bands = 3f;

    [Tooltip("_OutlineColor: color del contorno")]
    public bool overrideOutlineColor = false;
    public Color outlineColor = Color.black;

    [Tooltip("_OutlineWidth: grosor del contorno (0-10)")]
    public bool overrideOutlineWidth = false;
    [Range(0f, 10f)] public float outlineWidth = 0.5f;
}