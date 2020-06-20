const bool depthtex0MipmapEnabled = true;


vec3 RT(vec3 dir,vec3 position,float dither){

    vec3 clipPosition = toClipSpace3(position);
	    const float maxDistance = MAX_RAYLENGTH;
		float rayLength = ((position.z + dir.z * sqrt(3.0)*maxDistance) > -sqrt(3.0)*near) ? (-sqrt(3.0)*near -position.z) / dir.z : sqrt(3.0)*maxDistance;
		vec3 end = toClipSpace3(position+dir*rayLength);
        vec3 direction = end-clipPosition;  //convert to clip space
		float len = max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y)/36.;
		
    //get at which length the ray intersects with the edge of the screen
	
         vec3 maxLengths = (step(0.0,direction)-clipPosition) / direction;
         float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction/len;
	vec3 spos = clipPosition + stepv;
	spos.xy+=TAA_Offset*texelSize*0.5;
	
	

    for(int i = 0; i < min(len, mult*len)-2; i++){
			float sp= texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).x;
			if( sp < spos.z) {
				float dist = abs(linZ(sp)-linZ(spos.z))/linZ(spos.z);
				if (dist <= 0.1 ) return vec3(spos.xy, sp);
			}
			spos += stepv*0.25;
		}
    return vec3(1.1);
}


vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha*0.25 * n*frameCounter);
}


// with improvments from Bobcao3
vec3 cosineHemisphereSample(vec2 r)
{
    float phi = 2.0 * 3.1415926 * r.y;
    float sqrt_rx = sqrt(r.x);

    return vec3(cos(phi) * sqrt_rx, sin(phi) * sqrt_rx, sqrt(1.0 - r.x));
}
vec3 TangentToWorld(vec3 N, vec3 H)
{
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}

mat3 make_coord_space(vec3 n) {
    vec3 h = n;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
        h.x = 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
        h.y = 1.0;
    else
        h.z = 1.0;

    vec3 y = normalize(cross(h, n));
    vec3 x = normalize(cross(n, y));

    return mat3(x, y, n);
}
vec2 WeylNth(int n) {
	return fract(vec2(n * 12664745, n*9560333) / exp2(24.0));
}

// with improvments from Bobcao3
ivec2 iuv = ivec2(gl_FragCoord.st);
//float noise_sample = fract(bayer64(iuv))*10;
float noise_sample = fract(R2_dither()*3);
//float noise_sample = fract(blueNoise());
vec3 rtGI(vec3 normal,float noise,vec3 fragpos){
        mat3 obj2view = make_coord_space(normal);
	const int nrays = RAYS;
	const float num_directions = 4096 * nrays;
	vec3 intRadiance = vec3(0.0);
	for (int i = 0; i < nrays; i++){


		vec2 grid_sample = WeylNth(int(noise_sample * num_directions + (frameCounter & 0xFF) * num_directions + i));
		grid_sample.xy *= 0.8;
		vec3 object_space_sample = cosineHemisphereSample(grid_sample);
		vec3 rayDir = normalize(cosineHemisphereSample(grid_sample));
		rayDir = obj2view * object_space_sample;;
		//rayDir = TangentToWorld(normal,rayDir);
		vec3 rayHit = RT(mat3(gbufferModelView)*rayDir, fragpos, noise);


		if (rayHit.z <1.){

			vec4 fragpositionPrev = gbufferProjectionInverse * vec4(rayHit*2.-1.,1.);
			fragpositionPrev /= fragpositionPrev.w;
			vec3 sampleP = fragpositionPrev.xyz;
			fragpositionPrev = gbufferModelViewInverse * fragpositionPrev;
			vec4 previousPosition = fragpositionPrev + vec4(cameraPosition-previousCameraPosition,0.0);
			previousPosition = gbufferPreviousModelView * previousPosition;
			previousPosition = gbufferPreviousProjection * previousPosition;
			previousPosition.xy = previousPosition.xy/previousPosition.w*0.5+0.5;
			intRadiance += texture2D(colortex5,previousPosition.xy).rgb*150.0/4.0*3.0;
			
			
		}
		else {
			//vec3 sky_c = skyCloudsFromTex(rayDir,colortex4).rgb * float(rayDir.y > 0.0);
			vec3 sky_c = skyCloudsFromTex(rayDir,colortex4).rgb * float(rayDir.y > 1.0-eyeBrightnessSmooth.y/240.0);
			intRadiance += sky_c;
		}

	}
	return intRadiance/nrays;
}