
@group(0) @binding(0)
//var lutTex : texture_2d<f32>;
var lutTex : texture_storage_2d<r32float, write>;


// to be duplicated directly from "ShaderComp.wgsl" \/\/\/

struct sphereIntercept {
    secantLength : f32,
    ajacentDist : f32,
    bounded : bool,
    within : bool
}
const pi = 3.14159265359;
const sRadius = 1.0;
const shell = 1.05;

fn sampleDensity( pos: vec3<f32>, sPos: vec3<f32>, densityFalloff: f32, a: f32) -> f32 {
    //float altitude = length(pos-sPos)-sRadius;
    //float nAltitude = altitude/(shell-sRadius);
    var density = exp(-a*densityFalloff)*(1.0-a);
    return max(density,0.0)*1.0;//0.7;
}
fn sampleAltitude(uvPos: vec3<f32>, sPos: vec3<f32>, sRadius: f32, shell: f32) -> f32 {
    var altitude = length(uvPos-sPos)-sRadius;
    var altitudeSample = (altitude/(shell-sRadius));
    return altitudeSample;
}
fn sphereIntercepter(uvVec: vec3<f32>, uvPos: vec3<f32>, sPos: vec3<f32>, sRadius: f32) -> sphereIntercept {
    var ajacentDist = dot(uvVec,sPos-uvPos);
    var dist = length(uvPos-sPos);
    var within : bool = dist < sRadius;
    if ((ajacentDist > 0.0) || within) {
        
        //float ajacentDist = dot(uvVec,normalize(uvPos-sPos))*dist;


        var perpendicularDist = sqrt(-(ajacentDist*ajacentDist)+(dist*dist));
        var inteceptDist = sqrt((sRadius*sRadius)-(perpendicularDist*perpendicularDist));

        //vec3 close = uvPos+uvVec*(ajacentDist+inteceptDist);
        //vec3 far = uvPos+uvVec*(ajacentDist-inteceptDist);
        var bounded : bool = perpendicularDist < sRadius;


        return sphereIntercept(
        inteceptDist,
        ajacentDist,
        bounded,// if it intersects or not
        within // if the ray originates from within the sphere
        );
    }
    return sphereIntercept(
        -9999.0,
        9999.0,
        false,// if it intersects or not
        false// if the ray originates from within the sphere
    );
}

// to be duplicated directly from "ShaderComp.wgsl" /\/\/\

fn sRay( lVec: vec3<f32>, uvPos: vec3<f32>, sPos: vec3<f32>, sRadius: f32, lim: u32, stepLength: f32, shell: f32) -> f32 {
    var SI1 : sphereIntercept = sphereIntercepter(lVec, uvPos, sPos, sRadius);
    var SI2 : sphereIntercept = sphereIntercepter(lVec, uvPos, sPos, shell);
    var pos = vec3<f32>(0.0);
    var density = 0.0;
    var travel = 0.0;
    var a = 0.0;

    if (SI1.bounded) {
        return 2.0;
    } else {
        if (SI2.bounded) {
            travel = min((SI2.ajacentDist+SI2.secantLength),(SI1.ajacentDist-SI1.secantLength));
            if (SI2.within) {
                pos = uvPos;
            } else {
                travel = travel - ((SI2.ajacentDist-SI2.secantLength));
                pos = uvPos+lVec*((SI2.ajacentDist-SI2.secantLength));
            }

            var steps = min(u32(travel/stepLength),lim);
            a = sampleAltitude(pos, sPos, sRadius, shell);
            for (var x: u32=0;x<steps;x++) {
                var invShell = 1.0/(shell-sRadius);
                a += dot(lVec,normalize(pos-sPos))*stepLength*invShell;
                density += sampleDensity(pos, sPos, 2.0, a)*stepLength/sRadius;
                pos += lVec*stepLength;
            }
        }
    }
    return density;
}
fn opticalDepthLookupGen( sRadius: f32, lim: u32, stepLength: f32, shell: f32, coord: vec2<f32>) -> f32 {
    var opticalDepth = sRay(
    vec3(sin(coord.x*pi),cos(coord.x*pi),0.0), 
    vec3(0.0,sRadius+(coord.y*(shell-sRadius)),0.0), 
    vec3(0.0), sRadius, lim, stepLength, shell);
    return opticalDepth;
}

@compute @workgroup_size(8, 8)
fn gen_main(@builtin(global_invocation_id) id : vec3<u32>) {
    let size = textureDimensions(lutTex);
    if (id.x >= size.x || id.y >= size.y) {
        return;
    }

    let u = f32(id.x) / f32(size.x);
    let v = f32(id.y) / f32(size.y);
    let uv = vec2<f32>(u,v);

    let opticalDepth = opticalDepthLookupGen( sRadius, 5000u, sRadius*0.01, shell, uv);
    //let opticalDepth = f32(id.x)/256.0;

    textureStore(lutTex, id.xy, vec4<f32>(opticalDepth,0.0,0.0,1.0));
}
