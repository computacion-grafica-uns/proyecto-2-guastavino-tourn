using UnityEngine;

public class LightManager : MonoBehaviour
{
    private Light dirLight;
    private Light pointLight;
    private Light spotLight;

    private bool showMenu = true;
    private bool[] showPos = new bool[3];
    private bool[] showColor = new bool[3];
    private bool[] showRot = new bool[3];
    private float spotAngle = 60f;
    private string[][] rotFields = new string[3][];

    private string[][] posFields = new string[3][];
    private float[][] colorSliders = new float[3][];

    private string[] names = { "Direccional", "Point", "Spot" };

    void Awake()
    {
        CreateLights();

        for (int i = 0; i < 3; i++)
        {
            posFields[i] = new string[] { "0", "0", "0" }; 
            rotFields[i] = new string[] { "0", "0", "0" };
            colorSliders[i] = new float[] { 1f, 1f, 1f };
        }

        SyncFieldsFromLights();
    }

    // ── Creación de luces ──────────────────────────────────────────

    void CreateLights()
    {
        // Direccional
        var dGO = new GameObject("Dir Light");
        dGO.transform.SetParent(transform);
        dGO.transform.rotation = Quaternion.Euler(500f, 0f, 0f);
        dirLight = dGO.AddComponent<Light>();
        dirLight.type = LightType.Directional;
        dirLight.color = Color.white;
        dirLight.intensity = 1f;

        // Point
        var pGO = new GameObject("Point Light");
        pGO.transform.SetParent(transform);
        pGO.transform.position = new Vector3(500f, 0f, 0f);
        pointLight = pGO.AddComponent<Light>();
        pointLight.type = LightType.Point;
        pointLight.color = Color.white;
        pointLight.intensity = 1f;
        pointLight.range = 5000f;

        // Spot
        var sGO = new GameObject("Spot Light");
        sGO.transform.SetParent(transform);
        sGO.transform.position = new Vector3(400f, 0f, -25f);
        sGO.transform.rotation = Quaternion.Euler(320f, 330f, 0f);
        spotLight = sGO.AddComponent<Light>();
        spotLight.type = LightType.Spot;
        spotLight.color = Color.yellow;
        spotLight.intensity = 1f;
        spotLight.range = 5000f;
        spotAngle = spotLight.spotAngle = 60f;
    }

    void SyncFieldsFromLights()
    {
        Light[] lights = { dirLight, pointLight, spotLight };
        for (int i = 0; i < 3; i++)
        {
            Vector3 v = (lights[i].type == LightType.Directional)
                ? lights[i].transform.eulerAngles
                : lights[i].transform.position;

            posFields[i][0] = v.x.ToString("F1");
            posFields[i][1] = v.y.ToString("F1");
            posFields[i][2] = v.z.ToString("F1");

            colorSliders[i][0] = lights[i].color.r;
            colorSliders[i][1] = lights[i].color.g;
            colorSliders[i][2] = lights[i].color.b;

            var e = lights[i].transform.eulerAngles;
            rotFields[i][0] = e.x.ToString("F1");
            rotFields[i][1] = e.y.ToString("F1");
            rotFields[i][2] = e.z.ToString("F1");
        }
    }

    // ── Update: enviar globals a todos los shaders ─────────────────

    void Update()
    {
        PushToShaders();

        bool ctrl = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl);
        if (ctrl && Input.GetKeyDown(KeyCode.L))
            showMenu = !showMenu;
    }

    void PushToShaders()
    {
        // ── Direccional ──────────────────────────────────────────
        Vector3 dir = dirLight.transform.forward;
        Shader.SetGlobalVector("_DirLightDir", new Vector4(dir.x, dir.y, dir.z, 0f));
        Color c = dirLight.color * dirLight.intensity;
        Shader.SetGlobalVector("_DirLightColor",
            dirLight.enabled ? new Vector4(c.r, c.g, c.b, 1f) : Vector4.zero);

        // ── Point ────────────────────────────────────────────────
        Vector3 pp = pointLight.transform.position;
        Shader.SetGlobalVector("_PointLightPos",
            new Vector4(pp.x, pp.y, pp.z, 1f));
        Shader.SetGlobalVector("_PointLightColor",
            pointLight.enabled
                ? (Vector4)(pointLight.color * pointLight.intensity)
                : Vector4.zero);

        // ── Spot ─────────────────────────────────────────────────
        Vector3 sp = spotLight.transform.position;
        Vector3 sd = spotLight.transform.forward;
        float cosHA = Mathf.Cos(spotLight.spotAngle * 0.5f * Mathf.Deg2Rad);

        Shader.SetGlobalVector("_SpotLightPos",
            new Vector4(sp.x, sp.y, sp.z, 1f));
        Shader.SetGlobalVector("_SpotLightDir",
            new Vector4(sd.x, sd.y, sd.z, 0f));
        Shader.SetGlobalVector("_SpotLightColor",
            spotLight.enabled
                ? (Vector4)(spotLight.color * spotLight.intensity)
                : Vector4.zero);
        Shader.SetGlobalFloat("_SpotLightCosAngle", cosHA);


        Shader.SetGlobalFloat("_PointLightRange", pointLight.range);
        Shader.SetGlobalFloat("_SpotLightRange", spotLight.range);
        // Borde interno del cono (80% del ángulo) para el falloff suave:
        Shader.SetGlobalFloat("_SpotLightCosInner",
            Mathf.Cos(spotLight.spotAngle * 0.5f * 0.8f * Mathf.Deg2Rad));
    }

    // ── GUI ────────────────────────────────────────────────────────

    void OnGUI()
    {
        if (GUI.Button(new Rect(10, 10, 140, 28),
            showMenu ? "▲ Ocultar luces" : "▼ Mostrar luces"))
            showMenu = !showMenu;

        if (!showMenu) return;

        Light[] lights = { dirLight, pointLight, spotLight };
        float x = 10f, y = 46f, w = 340f;

        GUI.Box(new Rect(x - 4, y - 4, w + 8, 500f), "");

        for (int i = 0; i < 3; i++)
        {
            Light l = lights[i];

            // ── Toggle + nombre ───────────────────────────────────
            bool on = GUI.Toggle(new Rect(x, y, 180f, 24f), l.enabled, names[i]);
            if (on != l.enabled) l.enabled = on;
            y += 28f;

            // ── Posición ──────────────────────────────────────────
            string transformLabel = (l.type == LightType.Directional) ? "Rotación" : "Posición";
            if (GUI.Button(new Rect(x, y, 120f, 22f),
                (showPos[i] ? "▲ " : "▼ ") + transformLabel))
                showPos[i] = !showPos[i];
            y += 26f;

            if (showPos[i])
            {
                string[] axes = { "X", "Y", "Z" };
                for (int a = 0; a < 3; a++)
                {
                    GUI.Label(new Rect(x + a * 110f, y, 15f, 22f), axes[a]);
                    posFields[i][a] = GUI.TextField(
                        new Rect(x + a * 110f + 16f, y, 80f, 22f),
                        posFields[i][a]);
                }
                y += 26f;

                if (GUI.Button(new Rect(x, y, 80f, 22f), "Aplicar"))
                    ApplyTransform(i, l);
                y += 28f;
            }

            // ── Rotación (solo para Spot) ─────────────────────────
            if (l.type == LightType.Spot)
            {
                if (GUI.Button(new Rect(x, y, 120f, 22f),
                    (showRot[i] ? "▲ " : "▼ ") + "Rotación"))
                    showRot[i] = !showRot[i];
                y += 26f;

                if (showRot[i])
                {
                    string[] axes = { "X", "Y", "Z" };
                    for (int a = 0; a < 3; a++)
                    {
                        GUI.Label(new Rect(x + a * 110f, y, 15f, 22f), axes[a]);
                        rotFields[i][a] = GUI.TextField(
                            new Rect(x + a * 110f + 16f, y, 80f, 22f),
                            rotFields[i][a]);
                    }
                    y += 26f;

                    if (GUI.Button(new Rect(x, y, 80f, 22f), "Aplicar"))
                        ApplyRotation(i, l);
                    y += 28f;
                }
            }

            // ── Spot Angle (solo para Spot) ───────────────────────────
            if (l.type == LightType.Spot)
            {
                GUI.Label(new Rect(x, y, 220f, 22f),
                    $"Spot Angle: {spotAngle:F1}°");
                y += 24f;

                float newAngle = GUI.HorizontalSlider(
                    new Rect(x, y, 200f, 20f),
                    spotAngle, 1f, 179f);
                y += 28f;

                if (!Mathf.Approximately(newAngle, spotAngle))
                {
                    spotAngle = newAngle;
                    spotLight.spotAngle = spotAngle;
                }
            }

            // ── Color ─────────────────────────────────────────────
            if (GUI.Button(new Rect(x, y, 100f, 22f),
                showColor[i] ? "▲ Color" : "▼ Color"))
                showColor[i] = !showColor[i];
            y += 26f;

            if (showColor[i])
            {
                string[] ch = { "R", "G", "B" };
                for (int c = 0; c < 3; c++)
                {
                    GUI.Label(new Rect(x, y, 16f, 20f), ch[c]);
                    colorSliders[i][c] = GUI.HorizontalSlider(
                        new Rect(x + 18f, y + 4f, 200f, 16f),
                        colorSliders[i][c], 0f, 1f);
                    GUI.Label(new Rect(x + 224f, y, 40f, 20f),
                        colorSliders[i][c].ToString("F2"));
                    y += 24f;
                }

                l.color = new Color(
                    colorSliders[i][0],
                    colorSliders[i][1],
                    colorSliders[i][2]);

                // Preview del color
                var prev = GUI.color;
                GUI.color = l.color;
                GUI.DrawTexture(new Rect(x, y, w - 20f, 16f),
                    Texture2D.whiteTexture);
                GUI.color = prev;
                y += 24f;
            }

            // Separador
            GUI.Box(new Rect(x, y, w - 20f, 1f), "");
            y += 10f;
        }
    }

    void ApplyTransform(int i, Light l)
    {
        if (float.TryParse(posFields[i][0], out float px) &&
        float.TryParse(posFields[i][1], out float py) &&
        float.TryParse(posFields[i][2], out float pz))
        {
            if (l.type == LightType.Directional)
                l.transform.rotation = Quaternion.Euler(px, py, pz);
            else
                l.transform.position = new Vector3(px, py, pz);
        }
    }

    void ApplyRotation(int i, Light l)
    {
        if (float.TryParse(rotFields[i][0], out float rx) &&
            float.TryParse(rotFields[i][1], out float ry) &&
            float.TryParse(rotFields[i][2], out float rz))
        {
            l.transform.rotation = Quaternion.Euler(rx, ry, rz);
        }
    }
}