using UnityEngine;

// ============================================================
//  ResolvedMaterialConfig.cs
//  Resultado final del merge de todos los nodos de la jerarquía
//  para un tag dado. Cada propiedad tiene un flag "isSet".
// ============================================================

public class ResolvedMaterialConfig
{
    // ── Comunes ──────────────────────────────────────────────
    public bool ambientLightSet; public Color ambientLight = new Color(0.2f, 0.2f, 0.2f, 1f);
    public bool KaSet; public Color Ka = new Color(0.2f, 0.2f, 0.2f, 0f);
    public bool alphaSet; public float alpha = 1f;

    // ── Albedo ────────────────────────────────────────────────
    public bool albedoModeSet; public int albedoMode = 0;
    public bool baseColorSet; public Color baseColor = Color.white;
    public bool mainTexSet; public Texture2D mainTex;
    public bool tilingSet; public Vector2 tiling = Vector2.one;
    public bool offsetSet; public Vector2 offset = Vector2.zero;

    // ── Normal Map ────────────────────────────────────────────
    public bool normalMapSet; public Texture2D normalMap;
    public bool normalStrengthSet; public float normalStrength = 1f;

    // ── BP / Toon (compartidos) ───────────────────────────────
    public bool KdSet; public Color Kd = new Color(0.6f, 0.6f, 0.6f, 0f);
    public bool KsSet; public Color Ks = new Color(1f, 1f, 1f, 0f);
    public bool materialNSet; public float materialN = 32f;

    // ── Cook-Torrance ─────────────────────────────────────────
    public bool F0Set; public Color F0 = new Color(0.04f, 0.04f, 0.04f, 1f);
    public bool roughnessSet; public float roughness = 0.5f;
    public bool dMethodSet; public int dMethod = 0;
    public bool gMethodSet; public int gMethod = 0;

    // ── Toon ──────────────────────────────────────────────────
    public bool bandsSet; public float bands = 3f;
    public bool outlineColorSet; public Color outlineColor = Color.black;
    public bool outlineWidthSet; public float outlineWidth = 0.5f;

    // --------------------------------------------------------
    //  MergeWith: aplica solo los campos que el nodo activa
    // --------------------------------------------------------
    public void MergeWith(MaterialConfig c)
    {
        if (c == null) return;

        // Comunes
        if (c.overrideAmbientLight) { ambientLight = c.ambientLight; ambientLightSet = true; }
        if (c.overrideKa) { Ka = c.Ka; KaSet = true; }
        if (c.overrideAlpha) { alpha = c.alpha; alphaSet = true; }

        // Albedo
        if (c.overrideAlbedoMode) { albedoMode = c.albedoMode; albedoModeSet = true; }
        if (c.overrideBaseColor) { baseColor = c.baseColor; baseColorSet = true; }
        if (c.overrideMainTex) { mainTex = c.mainTex; mainTexSet = true; }
        if (c.overrideTiling) { tiling = c.tiling; tilingSet = true; }
        if (c.overrideOffset) { offset = c.offset; offsetSet = true; }

        // Normal Map
        if (c.overrideNormalMap) { normalMap = c.normalMap; normalMapSet = true; }
        if (c.overrideNormalStrength) { normalStrength = c.normalStrength; normalStrengthSet = true; }

        // BP / Toon
        if (c.overrideKd) { Kd = c.Kd; KdSet = true; }
        if (c.overrideKs) { Ks = c.Ks; KsSet = true; }
        if (c.overrideN) { materialN = c.materialN; materialNSet = true; }

        // Cook-Torrance
        if (c.overrideF0) { F0 = c.F0; F0Set = true; }
        if (c.overrideRoughness) { roughness = c.roughness; roughnessSet = true; }
        if (c.overrideDMethod) { dMethod = c.dMethod; dMethodSet = true; }
        if (c.overrideGMethod) { gMethod = c.gMethod; gMethodSet = true; }

        // Toon
        if (c.overrideBands) { bands = c.bands; bandsSet = true; }
        if (c.overrideOutlineColor) { outlineColor = c.outlineColor; outlineColorSet = true; }
        if (c.overrideOutlineWidth) { outlineWidth = c.outlineWidth; outlineWidthSet = true; }
    }
}