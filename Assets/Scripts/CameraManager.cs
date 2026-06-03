using UnityEngine;

/// <summary>
/// Crea la cámara principal, instancia los dos modos y alterna entre ellos.
/// Contiene toda la lógica de GUI.
///
/// Controles:
///   Tab          → alternar modo primera persona / orbital
///   Ctrl + C     → mostrar / ocultar menú
///   O (orbital)  → activar / desactivar focus
/// </summary>
public class CameraManager : MonoBehaviour
{
    // ── Inspector ──────────────────────────────────────────────────
    [Header("Posiciones y offsets iniciales")]
    [SerializeField] private Vector3 absoluteInitialPosition = new Vector3(0f, 0f, -200f);
    [SerializeField] private Vector3 initialOrbitTarget      = new Vector3(110f, 0f, 0f);
    [SerializeField] private Vector3 fpOffsetFromCenter      = new Vector3(0f, 0f, -200f);
    [SerializeField] private Vector3 orbitOffsetFromCenter   = new Vector3(0f, 60f, -200f);
    [SerializeField] private Transform[]   focusTargets;
    [SerializeField] private ObjectManager objectManager;

    [Header("Configuración Primera Persona")]
    [SerializeField] private float initialFPMoveSpeed = 100f;
    [SerializeField] private float initialFPRotSpeed = 90f;

    [Header("Configuración Orbital")]
    [SerializeField] private float initialOrbitSpeed = 80f;
    [SerializeField] private float initialOrbitZoomSpeed = 60f;
    [SerializeField] private float initialGlobalOrbitDistance = 200f;
    [SerializeField] private float initialFocusDistance = 30f;

    // ── Cámara ─────────────────────────────────────────────────────
    private Camera cam;

    // ── Submodos ───────────────────────────────────────────────────
    private FirstPersonCamera fpCam;
    private OrbitalCamera     orbitCam;

    // ── Estado ─────────────────────────────────────────────────────
    private bool orbitalMode           = false;
    private bool showMenu              = false;
    private bool gridCenterInitialized = false;

    // ──────────────────────────────────────────────────────────────
    //  Unity lifecycle
    // ──────────────────────────────────────────────────────────────

    void Start()
    {
        TryResolveObjectManager();
        CreateCamera();
        CreateSubModes();

        TrySetGridCenterTarget();
        ActivateCurrentMode();
    }

    void Update()
    {
        if (!gridCenterInitialized)
            TrySetGridCenterTarget();

        HandleGlobalInput();

        if (orbitalMode) orbitCam.Tick();
        else             fpCam.Tick();
    }

    // ──────────────────────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────────────────────

    void CreateCamera()
    {
        var go = new GameObject("MainCamera");
        go.tag = "MainCamera";

        cam = go.AddComponent<Camera>();
        cam.clearFlags      = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0.5f, 0.5f, 0.5f);
        cam.fieldOfView     = 60f;
        cam.nearClipPlane   = 0.1f;
        cam.farClipPlane    = 1000f;
        cam.transform.position = absoluteInitialPosition;
        cam.transform.rotation = Quaternion.identity;

        go.AddComponent<AudioListener>();
    }

    void CreateSubModes()
    {
        // Primera persona
        fpCam            = gameObject.AddComponent<FirstPersonCamera>();
        fpCam.moveSpeed  = initialFPMoveSpeed;
        fpCam.rotSpeed   = initialFPRotSpeed;

        // Orbital
        orbitCam = gameObject.AddComponent<OrbitalCamera>();
        orbitCam.orbitSpeed          = initialOrbitSpeed;
        orbitCam.zoomSpeed           = initialOrbitZoomSpeed;
        orbitCam.globalOrbitDistance = initialGlobalOrbitDistance;
        orbitCam.focusDistance       = initialFocusDistance;
        orbitCam.objectManager       = objectManager;
        orbitCam.focusTargets        = focusTargets;

        // Establecer el target inicial y el offset antes de que se recalcule por el ObjectManager (si existe)
        orbitCam.SetGlobalTarget(initialOrbitTarget, orbitOffsetFromCenter);
    }

    // ──────────────────────────────────────────────────────────────
    //  Input global
    // ──────────────────────────────────────────────────────────────

    void HandleGlobalInput()
    {
        // Tab: cambiar modo
        if (Input.GetKeyDown(KeyCode.Tab))
        {
            orbitalMode = !orbitalMode;
            ActivateCurrentMode();
        }

        // Ctrl + C: ocultar / mostrar menú
        bool ctrl = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl);
        if (ctrl && Input.GetKeyDown(KeyCode.C))
            showMenu = !showMenu;

        // O (sólo en orbital): toggle focus
        if (Input.GetKeyDown(KeyCode.O) && orbitalMode)
            orbitCam.ToggleFocus();
    }

    void ActivateCurrentMode()
    {
        if (orbitalMode) orbitCam.Activate(cam);
        else             fpCam.Activate(cam);
    }

    // ──────────────────────────────────────────────────────────────
    //  Grid / target helpers
    // ──────────────────────────────────────────────────────────────

    void TryResolveObjectManager()
    {
        if (objectManager == null)
            objectManager = FindObjectOfType<ObjectManager>();
    }

    void TrySetGridCenterTarget()
    {
        if (objectManager == null) return;

        var targets = objectManager.GetTeapotTransforms();
        if (targets == null || targets.Length == 0) return;

        // Calcular bounding center de todos los objetos
        Transform first = null;
        foreach (var t in targets)
        {
            if (t != null) { first = t; break; }
        }
        if (first == null) return;

        Bounds bounds = new Bounds(first.position, Vector3.zero);
        foreach (var t in targets)
            if (t != null) bounds.Encapsulate(t.position);

        Vector3 center = bounds.center;

        // Actualizar posición inicial de primera persona
        Vector3 fpInitPos = center + fpOffsetFromCenter;
        Vector3 toCenter  = center - fpInitPos;
        if (toCenter.sqrMagnitude > 0.0001f)
        {
            var fpEuler = Quaternion.LookRotation(toCenter, Vector3.up).eulerAngles;
            cam.transform.position = fpInitPos;
            cam.transform.rotation = Quaternion.Euler(fpEuler);
        }
        else
        {
            cam.transform.position = fpInitPos;
            // Opcional: reiniciar a una rotación base en lugar de mantener en la que estaba
            cam.transform.rotation = Quaternion.identity;
        }

        // Informar al modo orbital
        orbitCam.SetGlobalTarget(center, orbitOffsetFromCenter);

        gridCenterInitialized = true;

        // Re-inicializar el modo activo para reflejar los nuevos valores
        ActivateCurrentMode();
    }

    // ──────────────────────────────────────────────────────────────
    //  GUI
    // ──────────────────────────────────────────────────────────────

    void OnGUI()
    {
        float panelW = 240f;
        float x      = Screen.width - panelW - 10f;

        // Etiqueta de modo (siempre visible)
        GUI.Label(new Rect(x, 10f, panelW, 24f),
            orbitalMode ? "Modo: Orbital" : "Modo: Primera persona");

        if (!showMenu) return;

        float y = 60f;

        if (orbitalMode) DrawOrbitalGUI(x, ref y);
        else             DrawFirstPersonGUI(x, ref y);
    }

    void DrawOrbitalGUI(float x, ref float y)
    {
        Vector3 target = orbitCam.OrbitTarget;
        GUI.Label(new Rect(x, y, 240f, 24f),
            $"Target: ({target.x:F1}, {target.y:F1}, {target.z:F1})");
        y += 28f;

        GUI.Label(new Rect(x, y, 240f, 24f),
            orbitCam.FocusMode ? "Focus: ON" : "Focus: OFF");
        y += 28f;

        // Toggle panel de target manual
        string toggleLabel = orbitCam.ShowTargetUI ? "▲ Cambiar target" : "▼ Cambiar target";
        if (GUI.Button(new Rect(x, y, 130f, 24f), toggleLabel))
            orbitCam.ShowTargetUI = !orbitCam.ShowTargetUI;
        y += 28f;

        if (orbitCam.ShowTargetUI)
        {
            string[] axes = { "X", "Y", "Z" };
            for (int i = 0; i < 3; i++)
            {
                GUI.Label(new Rect(x, y, 16f, 24f), axes[i]);
                orbitCam.OrbitTargetFields[i] = GUI.TextField(
                    new Rect(x + 18f, y, 80f, 24f), orbitCam.OrbitTargetFields[i]);
                y += 28f;
            }

            if (GUI.Button(new Rect(x, y, 80f, 24f), "Aplicar"))
            {
                if (float.TryParse(orbitCam.OrbitTargetFields[0], out float tx) &&
                    float.TryParse(orbitCam.OrbitTargetFields[1], out float ty) &&
                    float.TryParse(orbitCam.OrbitTargetFields[2], out float tz))
                {
                    orbitCam.ApplyManualTarget(new Vector3(tx, ty, tz));
                }
            }
            y += 32f;
        }

        // Sliders
        GUI.Label(new Rect(x, y, 240f, 24f), $"Velocidad orbital: {orbitCam.OrbitSpeed:F0}");
        y += 24f;
        orbitCam.OrbitSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), orbitCam.OrbitSpeed, 10f, 300f);
        y += 28f;

        GUI.Label(new Rect(x, y, 240f, 24f), $"Velocidad Zoom: {orbitCam.ZoomSpeed:F1}");
        y += 24f;
        orbitCam.ZoomSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), orbitCam.ZoomSpeed, 50f, 200f);
    }

    void DrawFirstPersonGUI(float x, ref float y)
    {
        GUI.Label(new Rect(x, y, 240f, 24f), $"Velocidad movimiento: {fpCam.moveSpeed:F1}");
        y += 24f;
        fpCam.moveSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), fpCam.moveSpeed, 1f, 300f);
        y += 28f;

        GUI.Label(new Rect(x, y, 240f, 24f), $"Velocidad rotación: {fpCam.rotSpeed:F0}");
        y += 24f;
        fpCam.rotSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), fpCam.rotSpeed, 10f, 360f);
    }
}
