import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

let scene, camera, renderer, controls;
let model;

const raycaster = new THREE.Raycaster();
const mouse = new THREE.Vector2();

const nodes = [];
const nodeMarkers = [];
const edges = [];
let connectMode = false;
let selectedNode = null;

const TYPE_COLORS = {
    start: 0x00ff00,       // 🟢 Green
    waypoint: 0x0088ff,    // 🔵 Blue
    destination: 0xff0000  // 🔴 Red
};

init();
animate();

function init() {
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf0f0f0);

    camera = new THREE.PerspectiveCamera(
        60,
        window.innerWidth / window.innerHeight,
        0.1,
        1000
    );
    camera.position.set(5, 5, 10);

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    document.body.appendChild(renderer.domElement);

    controls = new OrbitControls(camera, renderer.domElement);

    // Lights
    scene.add(new THREE.AmbientLight(0xffffff, 1.5));
    const light = new THREE.DirectionalLight(0xffffff, 2);
    light.position.set(5, 10, 5);
    scene.add(light);

    // Grid
    scene.add(new THREE.GridHelper(100, 100));

    // Load Model
    const loader = new GLTFLoader();
    loader.load(
        "model/sample1.glb",
        (gltf) => {
            model = gltf.scene;
            scene.add(model);
            console.log("Model Loaded");
        },
        undefined,
        (error) => console.error(error)
    );

    // Listeners
    window.addEventListener("click", onMouseClick);
    window.addEventListener("resize", onResize);

    const connectBtn = document.getElementById("connectBtn");
    connectBtn.addEventListener("click", () => {
        connectMode = !connectMode;
        if (selectedNode) {
            selectedNode.material.emissive.setHex(0x000000);
            selectedNode = null;
        }
        connectBtn.innerText = connectMode ? "Connect Mode: ON" : "Connect Mode: OFF";
        connectBtn.classList.toggle("active", connectMode);
    });

    document.getElementById("downloadBtn").addEventListener("click", downloadJSON);
}

function onMouseClick(event) {
    if (event.target.closest("#toolbar")) return;

    mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
    mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;

    raycaster.setFromCamera(mouse, camera);

    // Mode 1: Connecting Nodes
    if (connectMode) {
        const markerHits = raycaster.intersectObjects(nodeMarkers);
        if (markerHits.length > 0) {
            const clickedMarker = markerHits[0].object;

            // First node selection
            if (!selectedNode) {
                selectedNode = clickedMarker;
                selectedNode.material.emissive.setHex(0xffff00); // Yellow glow on active
                return;
            }

            // Deselect if clicked same node twice
            if (selectedNode === clickedMarker) {
                selectedNode.material.emissive.setHex(0x000000);
                selectedNode = null;
                return;
            }

            // Second node selected -> create edge
            createEdge(selectedNode, clickedMarker);
            selectedNode.material.emissive.setHex(0x000000);
            selectedNode = null;
        }
        return;
    }

    // Mode 2: Adding New Nodes
    if (!model) return;
    const intersects = raycaster.intersectObject(model, true);
    if (intersects.length === 0) return;

    const point = intersects[0].point;
    const nameInput = document.getElementById("nodeName").value.trim();
    const type = document.getElementById("nodeType").value;
    const nodeId = "N" + (nodes.length + 1);
    const nodeName = nameInput || (type.charAt(0).toUpperCase() + type.slice(1) + " " + (nodes.length + 1));
    const markerColor = TYPE_COLORS[type] || 0x0088ff;

    const marker = new THREE.Mesh(
        new THREE.SphereGeometry(0.12, 16, 16),
        new THREE.MeshStandardMaterial({
            color: markerColor,
            roughness: 0.3,
            metalness: 0.1
        })
    );
    marker.position.copy(point);

    marker.userData = {
        id: nodeId,
        name: nodeName,
        type: type
    };

    scene.add(marker);
    nodeMarkers.push(marker);

    // Exact output structure requested
    const nodeData = {
        id: nodeId,
        name: nodeName,
        type: type,
        position: {
            x: Number(point.x.toFixed(3)),
            y: Number(point.y.toFixed(3)),
            z: Number(point.z.toFixed(3))
        }
    };

    nodes.push(nodeData);
    document.getElementById("nodeName").value = "";
}

function createEdge(nodeA, nodeB) {
    const fromId = nodeA.userData.id;
    const toId = nodeB.userData.id;

    // Prevent duplicate edges between the same two nodes
    const exists = edges.some(e => 
        (e.from === fromId && e.to === toId) || 
        (e.from === toId && e.to === fromId)
    );
    if (exists) return;

    // Draw yellow path line
    const geometry = new THREE.BufferGeometry().setFromPoints([
        nodeA.position,
        nodeB.position
    ]);

    const material = new THREE.LineBasicMaterial({
        color: 0xffff00,
        linewidth: 3
    });

    const line = new THREE.Line(geometry, material);
    scene.add(line);

    // Calculate Euclidean distance
    const distance = Number(nodeA.position.distanceTo(nodeB.position).toFixed(2));

    const edgeData = {
        from: fromId,
        to: toId,
        distance: distance
    };

    edges.push(edgeData);
}

function downloadJSON() {
    const data = {
        nodes: nodes,
        edges: edges
    };

    const json = JSON.stringify(data, null, 2);
    const blob = new Blob([json], { type: "application/json" });
    const url = URL.createObjectURL(blob);

    const a = document.createElement("a");
    a.href = url;
    a.download = "navigation.json";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

function animate() {
    requestAnimationFrame(animate);
    controls.update();
    renderer.render(scene, camera);
}

function onResize() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
}