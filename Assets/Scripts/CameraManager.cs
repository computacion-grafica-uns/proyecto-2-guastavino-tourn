using System.Collections.Generic;
using UnityEngine;

public class CameraManager : MonoBehaviour
{
    // ── Referencia a la cámara ─────────────────────────────────────
    private Camera cam;
    private Vector3 initialPosition = new Vector3(0f, 0f, -200f);
    private Vector3 initialRotation = new Vector3(0f, 0f, 0f);
    [SerializeField] private Vector3 fpOffsetFromCenter = new Vector3(0f, 0f, -200f);
    [SerializeField] private Vector3 orbitOffsetFromCenter = new Vector3(0f, 60f, -200f);

    // ── Modo ───────────────────────────────────────────────────────
    private bool orbitalMode = false;

    // ── Primera persona ───────────────────────────────────────────
    private Vector3 fpPos;
    private float yaw = 0f;
    private float pitch = 0f;
    private float fpSpeed = 100f;
    private float rotSpeed = 90f;

    // ── Orbital ───────────────────────────────────────────────────
    private Vector3 orbitTargetGlobal = new Vector3(110f, 0f, 0f);
    private Vector3 orbitTargetFocus = new Vector3(110f, 0f, 0f);
    private Vector3 orbitTarget;
    private float orbitDistance = 200f;
    private float orbitYaw = 180f;
    private float orbitPitch = 30f;
    private float orbitSpeed = 80f;
    private float zoomSpeed = 60f;

    // ── Orbital focus ─────────────────────────────────────────────
    [SerializeField] private Transform[] focusTargets;
    [SerializeField] private ObjectManager objectManager;
    private bool focusMode = false;
    private int focusIndex = 0;
    private int focusRow = 0;
    private int focusColumn = 0;
    private bool gridCenterInitialized = false;

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
        TryResolveObjectManager();

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

        TrySetGridCenterTarget();
        InitFirstPerson();
    }


    void Update()
    {
        if (!gridCenterInitialized)
            TrySetGridCenterTarget();

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
            EnsureFocusTargets();
            if (focusTargets == null || focusTargets.Length == 0) return;

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
        orbitTarget = focusMode ? orbitTargetFocus : orbitTargetGlobal;
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

        int rows = objectManager != null ? objectManager.Rows : 0;
        int columns = objectManager != null ? objectManager.Columns : 0;
        bool hasGrid = rows > 0 && columns > 0;

        if (hasGrid && focusTargets.Length != rows * columns)
        {
            focusTargets = objectManager.GetTeapotTransforms();
            if (focusTargets.Length == 0) return;
        }

        bool moved = false;
        int newRow = focusRow;
        int newColumn = focusColumn;

        if (Input.GetKeyDown(KeyCode.UpArrow))
        {
            newRow = hasGrid ? (focusRow - 1 + rows) % rows : focusRow;
            moved = true;
        }
        if (Input.GetKeyDown(KeyCode.DownArrow))
        {
            newRow = hasGrid ? (focusRow + 1) % rows : focusRow;
            moved = true;
        }
        if (Input.GetKeyDown(KeyCode.LeftArrow))
        {
            if (hasGrid)
            {
                if (focusColumn == 0)
                {
                    newRow = (focusRow - 1 + rows) % rows;
                    newColumn = columns - 1;
                }
                else
                {
                    newColumn = focusColumn - 1;
                }
            }
            moved = true;
        }
        if (Input.GetKeyDown(KeyCode.RightArrow))
        {
            if (hasGrid)
            {
                if (focusColumn == columns - 1)
                {
                    newRow = (focusRow + 1) % rows;
                    newColumn = 0;
                }
                else
                {
                    newColumn = focusColumn + 1;
                }
            }
            moved = true;
        }

        if (!moved) return;

        focusRow = newRow;
        focusColumn = newColumn;

        if (hasGrid)
        {
            int nextIndex = (focusRow * columns) + focusColumn;
            ApplyFocusTarget(nextIndex, false);
            return;
        }

        int dir = 0;
        if (Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.DownArrow)) dir = 1;
        if (Input.GetKeyDown(KeyCode.LeftArrow) || Input.GetKeyDown(KeyCode.UpArrow)) dir = -1;
        if (dir == 0) return;

        int fallbackIndex = (focusIndex + dir + focusTargets.Length) % focusTargets.Length;
        ApplyFocusTarget(fallbackIndex, false);
    }

    void ApplyFocusTarget(int index, bool force)
    {
        if (focusTargets == null || focusTargets.Length == 0) return;

        if (!force && index == focusIndex) return;
        focusIndex = Mathf.Clamp(index, 0, focusTargets.Length - 1);

        if (objectManager != null)
        {
            int rows = objectManager.Rows;
            int columns = objectManager.Columns;
            if (rows > 0 && columns > 0)
            {
                focusRow = focusIndex / columns;
                focusColumn = focusIndex % columns;
            }
        }

        Transform target = focusTargets[focusIndex];
        if (target == null) return;

        Vector3 targetCenter = target.position;
        var renderers = target.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length > 0)
        {
            Bounds bounds = renderers[0].bounds;
            for (int i = 1; i < renderers.Length; i++)
            {
                bounds.Encapsulate(renderers[i].bounds);
            }
            targetCenter = bounds.center;
        }

        orbitTargetFocus = targetCenter;
        orbitTarget = orbitTargetFocus;
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

        orbitTarget = orbitTargetGlobal;
        ApplyOrbital();
    }

    void EnsureFocusTargets()
    {
        if (focusTargets != null && focusTargets.Length > 0) return;

        TryResolveObjectManager();

        if (objectManager != null)
        {
            focusTargets = objectManager.GetTeapotTransforms();
            if (focusTargets.Length > 0)
            {
                int columns = objectManager.Columns;
                focusIndex = Mathf.Clamp(focusIndex, 0, focusTargets.Length - 1);
                focusRow = columns > 0 ? focusIndex / columns : 0;
                focusColumn = columns > 0 ? focusIndex % columns : 0;
                return;
            }
        }

        var renderers = FindObjectsOfType<Renderer>(true);
        var unique = new HashSet<Transform>();
        var list = new List<Transform>();

        foreach (var renderer in renderers)
        {
            if (renderer == null) continue;
            Transform root = renderer.transform.root;
            if (root == null) continue;
            if (root == transform) continue;

            if (unique.Add(root)) list.Add(root);
        }

        focusTargets = list.ToArray();

        if (focusTargets.Length == 0)
            Debug.LogWarning("CameraManager: no se encontraron objetos para focus.");
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

    void TryResolveObjectManager()
    {
        if (objectManager != null) return;
        objectManager = FindObjectOfType<ObjectManager>();
    }

    void TrySetGridCenterTarget()
    {
        if (objectManager == null) return;

        var targets = objectManager.GetTeapotTransforms();
        if (targets == null || targets.Length == 0) return;

        Transform first = null;
        for (int i = 0; i < targets.Length; i++)
        {
            if (targets[i] == null) continue;
            first = targets[i];
            break;
        }

        if (first == null) return;

        Bounds bounds = new Bounds(first.position, Vector3.zero);
        for (int i = 0; i < targets.Length; i++)
        {
            if (targets[i] == null) continue;
            bounds.Encapsulate(targets[i].position);
        }

        orbitTargetGlobal = bounds.center;
        orbitTargetFields[0] = orbitTargetGlobal.x.ToString("F1");
        orbitTargetFields[1] = orbitTargetGlobal.y.ToString("F1");
        orbitTargetFields[2] = orbitTargetGlobal.z.ToString("F1");
        gridCenterInitialized = true;

        UpdateInitialFromCenter(orbitTargetGlobal);
    }

    void UpdateInitialFromCenter(Vector3 center)
    {
        initialPosition = center + fpOffsetFromCenter;

        Vector3 toCenter = center - initialPosition;
        if (toCenter.sqrMagnitude > 0.0001f)
            initialRotation = Quaternion.LookRotation(toCenter, Vector3.up).eulerAngles;

        if (!orbitalMode)
        {
            fpPos = initialPosition;
            yaw = initialRotation.y;
            pitch = initialRotation.x;
            ApplyFirstPerson();
        }

        float orbitDistanceLocal = orbitOffsetFromCenter.magnitude;
        if (orbitDistanceLocal > 0.001f)
        {
            orbitDistance = orbitDistanceLocal;
            Vector3 dir = orbitOffsetFromCenter / orbitDistanceLocal;
            orbitPitch = Mathf.Asin(Mathf.Clamp(dir.y, -1f, 1f)) * Mathf.Rad2Deg;
            orbitYaw = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
        }

        if (!focusMode)
        {
            orbitTarget = orbitTargetGlobal;
            if (orbitalMode) ApplyOrbital();
        }
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
                        orbitTargetGlobal = new Vector3(tx, ty, tz);
                        orbitTarget = orbitTargetGlobal;
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
            zoomSpeed = GUI.HorizontalSlider(new Rect(x, y, 180f, 20f), zoomSpeed, 50f, 200f);
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
