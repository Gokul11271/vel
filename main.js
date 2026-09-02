import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';

let scene,camera,renderer,controls;
let model;

const raycaster = new THREE.Raycaster();
const mouse = new THREE.Vector2();

const nodes=[];

init();
animate();

function init(){

    scene=new THREE.Scene();
    scene.background=new THREE.Color(0xf0f0f0);

    camera=new THREE.PerspectiveCamera(
        60,
        window.innerWidth/window.innerHeight,
        0.1,
        1000
    );

    camera.position.set(5,5,10);

    renderer=new THREE.WebGLRenderer({antialias:true});
    renderer.setSize(window.innerWidth,window.innerHeight);

    document.body.appendChild(renderer.domElement);

    controls=new OrbitControls(camera,renderer.domElement);

    //----------------------------------------
    // Lights
    //----------------------------------------

    scene.add(new THREE.AmbientLight(0xffffff,1.5));

    const light=new THREE.DirectionalLight(0xffffff,2);

    light.position.set(5,10,5);

    scene.add(light);

    //----------------------------------------
    // Grid
    //----------------------------------------

    scene.add(new THREE.GridHelper(100,100));

    //----------------------------------------
    // Load GLB
    //----------------------------------------

    const loader=new GLTFLoader();

    loader.load(

        "model/sample1.glb",

        function(gltf){

            model=gltf.scene;

            scene.add(model);

            console.log("Model Loaded");

        },

        undefined,

        function(error){

            console.error(error);

        }

    );

    //----------------------------------------

    window.addEventListener("click",onMouseClick);

    window.addEventListener("resize",onResize);

    document
        .getElementById("downloadBtn")
        .addEventListener("click",downloadJSON);

}

function onMouseClick(event){

    if(!model) return;

    mouse.x=(event.clientX/window.innerWidth)*2-1;

    mouse.y=-(event.clientY/window.innerHeight)*2+1;

    raycaster.setFromCamera(mouse,camera);

    const intersects=raycaster.intersectObject(model,true);

    if(intersects.length===0) return;

    const point=intersects[0].point;

    //----------------------------------------
    // Marker
    //----------------------------------------

    const marker=new THREE.Mesh(

        new THREE.SphereGeometry(0.08,16,16),

        new THREE.MeshBasicMaterial({
            color:0xff0000
        })

    );

    marker.position.copy(point);

    scene.add(marker);

    //----------------------------------------
    // Node Name
    //----------------------------------------

    let name=prompt("Destination Name");

    if(name===null || name==="")
        name="Node_"+(nodes.length+1);

    //----------------------------------------

    const node={

        id:nodes.length+1,

        name:name,

        x:Number(point.x.toFixed(3)),

        y:Number(point.y.toFixed(3)),

        z:Number(point.z.toFixed(3))

    };

    nodes.push(node);

    console.log(node);

    console.log(nodes);

}

function downloadJSON(){

    const json=JSON.stringify(nodes,null,4);

    const blob=new Blob([json],{
        type:"application/json"
    });

    const url=URL.createObjectURL(blob);

    const a=document.createElement("a");

    a.href=url;

    a.download="nodes.json";

    document.body.appendChild(a);

    a.click();

    document.body.removeChild(a);

    URL.revokeObjectURL(url);

}

function animate(){

    requestAnimationFrame(animate);

    controls.update();

    renderer.render(scene,camera);

}

function onResize(){

    camera.aspect=window.innerWidth/window.innerHeight;

    camera.updateProjectionMatrix();

    renderer.setSize(window.innerWidth,window.innerHeight);

}