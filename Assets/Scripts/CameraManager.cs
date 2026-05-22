using UnityEngine;

public class CameraManager : MonoBehaviour
{
    // ── Referencia a la cámara ─────────────────────────────────────
    private Camera cam;
    private Vector3 initialPosition = new Vector3(110f, 0f, -200f);
    private Vector3 initialRotation = new Vector3(0f, 0f, 0f);

    // ── Modo ───────────────────────────────────────────────────────
    private bool orbitalMode = false;

    // ── Primera persona ───────────────────────────────────────────
    private Vector3 fpPos;
    private float yaw = 0f;
    private float pitch = 0f;
    private float fpSpeed = 100f;
    private float rotSpeed = 90f;

    // ── Orbital ───────────────────────────────────────────────────
    private Vector3 orbitTarget = new Vector3(110f, 0f, 0f);
    private float orbitDistance = 200f;
    private float orbitYaw = 180f;
    private float orbitPitch = 30f;
    private float orbitSpeed = 80f;
    private float zoomSpeed = 15f;

    // ── Orbital focus ─────────────────────────────────────────────
    [SerializeField] private Transform[] focusTargets;
    private bool focusMode = false;
    private int focusIndex = 0;

    // ── Config cámara ─────────────────────────────────────────────
    private float fov = 60f;
    private float nearClip = 0.1f;
    private float farClip = 1000f;

    // ── GUI ────────────────────────────────────────────────────────
    private bool showMenu = true;
    private bool showTargetUI = false;
    private string[] orbitTargetFields = { "110", "0", "0" };

    void Start()
    {
        // Crear GameObject con Camera
        var go = new GameObject("MainCamera");
        go.tag = "MainCamera";
        cam = go.AddComponent<Camera>();

        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0.1f, 0.1f, 0.1f);
        cam.fieldOfView = fov;
        cam.nearClipPlane = nearClip;
        cam.farClipPlane = farClip;
        cam.transform.position = initialPosition;
        cam.transform.rotation = Quaternion.Euler(initialRotation);

        fpPos = initialPosition;
        // Agregar AudioListener para evitar warnings de Unity
        go.AddComponent<AudioListener>();

        InitFirstPerson();
    }


    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Tab))
        {
            orbitalMode = !orbitalMode;
            if (orbitalMode) InitOrbital();
            else InitFirstPerson();
        }

        bool ctrl = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl);
        if (ctrl && Input.GetKeyDown(KeyCode.C))
            showMenu = !showMenu;

        if (Input.GetKeyDown(KeyCode.O) && orbitalMode)
        {
            focusMode = !focusMode;
            if (focusMode) ApplyFocusTarget(focusIndex, true);
            else RestoreFocusTargets();
        }

        if (orbitalMode) UpdateOrbital();
        else UpdateFirstPerson();
    }

    void InitFirstPerson()
    {
        fpPos = cam.transform.position;

        Vector3 euler = cam.transform.eulerAngles;

        yaw = euler.y;
        pitch = euler.x;

        ApplyFirstPerson();
    }
    void UpdateFirstPerson()
    {
        // ── Rotación con flechas ───────────────────────────────────
        if (Input.GetKey(KeyCode.LeftArrow)) yaw -= rotSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.RightArrow)) yaw += rotSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.DownArrow)) pitch += rotSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.UpArrow)) pitch -= rotSpeed * Time.deltaTime;
        pitch = Mathf.Clamp(pitch, -89f, 89f);

        // ── Movimiento con WASD ───────────────────────────────────
        var rot = Quaternion.Euler(pitch, yaw, 0f);
        Vector3 forward = rot * Vector3.forward;
        Vector3 right = rot * Vector3.right;

        // Movimiento en plano horizontal (sin pitch para WASD)
        Vector3 flatForward = new Vector3(forward.x, 0f, forward.z).normalized;
        Vector3 moveDir = Vector3.zero;

        if (Input.GetKey(KeyCode.W)) moveDir += flatForward;
        if (Input.GetKey(KeyCode.S)) moveDir -= flatForward;
        if (Input.GetKey(KeyCode.A)) moveDir -= right;
        if (Input.GetKey(KeyCode.D)) moveDir += right;

        // Subir / bajar
        if (Input.GetKey(KeyCode.Space)) moveDir += Vector3.up;
        if (Input.GetKey(KeyCode.LeftShift)) moveDir -= Vector3.up;

        if (moveDir != Vector3.zero)
            fpPos += moveDir.normalized * fpSpeed * Time.deltaTime;

        ApplyFirstPerson();
    }

    void ApplyFirstPerson()
    {
        cam.transform.position = fpPos;
        cam.transform.rotation = Quaternion.Euler(pitch, yaw, 0f);
    }

    void InitOrbital()
    {
        orbitDistance = 200f;
        orbitYaw = 180f;
        orbitPitch = 30f;
        ApplyOrbital();
    }

    void UpdateOrbital()
    {
        if (focusMode) UpdateFocusCycling();

        bool ctrl = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl);
        bool blockArrowRotation = focusMode;

        // ── Rotar alrededor del target ────────────────────────────
        if (Input.GetKey(KeyCode.A) || (!blockArrowRotation && Input.GetKey(KeyCode.LeftArrow)))
            orbitYaw -= orbitSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.D) || (!blockArrowRotation && Input.GetKey(KeyCode.RightArrow)))
            orbitYaw += orbitSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.W) || (!blockArrowRotation && Input.GetKey(KeyCode.UpArrow)))
            orbitPitch += orbitSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.S) || (!blockArrowRotation && Input.GetKey(KeyCode.DownArrow)))
            orbitPitch -= orbitSpeed * Time.deltaTime;

        orbitPitch = Mathf.Clamp(orbitPitch, -89f, 89f);

        // ── Zoom ──────────────────────────────────────────────────
        if (Input.GetKey(KeyCode.Space)) orbitDistance -= zoomSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.LeftShift)) orbitDistance += zoomSpeed * Time.deltaTime;
        orbitDistance = Mathf.Max(1f, orbitDistance);

        ApplyOrbital();
    }

    void UpdateFocusCycling()
    {
        if (focusTargets == null || focusTargets.Length == 0) return;

        int dir = 0;
        if (Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.DownArrow)) dir = 1;
        if (Input.GetKeyDown(KeyCode.LeftArrow) || Input.GetKeyDown(KeyCode.UpArrow)) dir = -1;
        if (dir == 0) return;

        int nextIndex = (focusIndex + dir + focusTargets.Length) % focusTargets.Length;
        ApplyFocusTarget(nextIndex, false);
    }

    void ApplyFocusTarget(int index, bool force)
    {
        if (focusTargets == null || focusTargets.Length == 0) return;

        if (!force && index == focusIndex) return;
        focusIndex = Mathf.Clamp(index, 0, focusTargets.Length - 1);

        Transform target = focusTargets[focusIndex];
        if (target == null) return;

        orbitTarget = target.position;
        ApplyOrbital();

        for (int i = 0; i < focusTargets.Length; i++)
        {
            if (focusTargets[i] == null) continue;
            focusTargets[i].gameObject.SetActive(i == focusIndex);
        }
    }

    void RestoreFocusTargets()
    {
        if (focusTargets == null) return;

        for (int i = 0; i < focusTargets.Length; i++)
        {
            if (focusTargets[i] == null) continue;
            focusTargets[i].gameObject.SetActive(true);
        }
    }

    void ApplyOrbital()
    {
        float pitchRad = orbitPitch * Mathf.Deg2Rad;
        float yawRad = orbitYaw * Mathf.Deg2Rad;

        Vector3 offset = new Vector3(
            Mathf.Cos(pitchRad) * Mathf.Sin(yawRad),
            Mathf.Sin(pitchRad),
            Mathf.Cos(pitchRad) * Mathf.Cos(yawRad)
        ) * orbitDistance;

        cam.transform.position = orbitTarget + offset;
        cam.transform.LookAt(orbitTarget, Vector3.up);
    }

    void OnGUI()
    {
        float panelW = 240f;
        float x = Screen.width - panelW - 10f;   // margen de 10 px del borde derecho

        string modeLabel = orbitalMode ? "Modo: Orbital" : "Modo: Primera persona";
        GUI.Label(new Rect(x, 10, panelW, 24), modeLabel);

        if (!showMenu) return;

        float y = 60f;

        if (orbitalMode)
        {
            // ── Target ────────────────────────────────────────────────
            GUI.Label(new Rect(x, y, panelW, 24),
                $"Target: ({orbitTarget.x:F1}, {orbitTarget.y:F1}, {orbitTarget.z:F1})");
            y += 28f;

            string focusLabel = focusMode ? "Focus: ON" : "Focus: OFF";
            GUI.Label(new Rect(x, y, panelW, 24), focusLabel);
            y += 28f;

            if (GUI.Button(new Rect(x, y, 130, 24),
                showTargetUI ? "▲ Cambiar target" : "▼ Cambiar target"))
                showTargetUI = !showTargetUI;
            y += 28f;

            if (showTargetUI)
            {
                string[] axes = { "X", "Y", "Z" };
                for (int i = 0; i < 3; i++)
                {
                    GUI.Label(new Rect(x, y, 16f, 24f), axes[i]);
                    orbitTargetFields[i] = GUI.TextField(
                        new Rect(x + 18f, y, 80f, 24f), orbitTargetFields[i]);
                    y += 28f;
                }

                if (GUI.Button(new Rect(x, y, 80, 24), "Aplicar"))
                {
                    if (float.TryParse(orbitTargetFields[0], out float tx) &&
                        float.TryParse(orbitTargetFields[1], out float ty) &&
                        float.TryParse(orbitTargetFields[2], out float tz))
                    {
                        orbitTarget = new Vector3(tx, ty, tz);
                        ApplyOrbital();
                    }
                }
                y += 32f;
            }

            // ── Velocidades orbital ───────────────────────────────────
            GUI.Label(new Rect(x, y, panelW, 24), $"Velocidad orbital: {orbitSpeed:F0}");
            y += 24f;
            orbitSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), orbitSpeed, 10f, 300f);
            y += 28f;

            GUI.Label(new Rect(x, y, panelW, 24), $"Velocidad Zoom: {zoomSpeed:F1}");
            y += 24f;
            zoomSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), zoomSpeed, 1f, 60f);
        }
        else
        {
            // ── Velocidades primera persona ───────────────────────────
            GUI.Label(new Rect(x, y, panelW, 24), $"Velocidad movimiento: {fpSpeed:F1}");
            y += 24f;
            fpSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), fpSpeed, 1f, 300f);
            y += 28f;

            GUI.Label(new Rect(x, y, panelW, 24), $"Velocidad rotación: {rotSpeed:F0}");
            y += 24f;
            rotSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), rotSpeed, 10f, 360f);
        }
    }
}
