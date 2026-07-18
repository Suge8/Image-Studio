<script>
  import { onMount } from 'svelte';

  /* WebGL 流体渐变：domain-warped fbm，品牌四色，跟随指针轻移。
     无 WebGL 时回退到纯 CSS aurora。 */
  let canvas;
  let fallback = false;

  const VERT = `attribute vec2 p; void main(){ gl_Position = vec4(p,0.,1.); }`;
  const FRAG = `
precision highp float;
uniform vec2 res; uniform float t; uniform vec2 mouse;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f*f*(3.-2.*f);
  return mix(mix(hash(i), hash(i+vec2(1,0)), u.x),
             mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), u.x), u.y);
}
float fbm(vec2 p){
  float v = 0., a = .55;
  for(int i=0;i<4;i++){ v += a*noise(p); p = p*2.05 + vec2(3.7, 1.3); a *= .5; }
  return v;
}
void main(){
  vec2 uv = gl_FragCoord.xy / res;
  vec2 p = uv; p.x *= res.x/res.y;
  vec2 m = (mouse - .5) * .3;
  float q = fbm(p*1.35 + vec2(t*.045, -t*.03) + m);
  float w = fbm(p*1.15 + q*1.4 + vec2(-t*.035, t*.05));
  float r = fbm(p*.9 + w*1.2 + vec2(t*.025, t*.02));
  vec3 paper = vec3(.988, .984, .992);
  vec3 coral = vec3(.949, .545, .424);
  vec3 violet = vec3(.62, .48, .93);
  vec3 sky = vec3(.42, .55, .96);
  vec3 col = paper;
  col = mix(col, coral, smoothstep(.52, .95, q) * .34);
  col = mix(col, violet, smoothstep(.55, 1., w) * .26);
  col = mix(col, sky, smoothstep(.58, 1.05, r) * .3);
  gl_FragColor = vec4(col, 1.);
}`;

  onMount(() => {
    const gl = canvas.getContext('webgl', { antialias: false, alpha: false });
    if (!gl) { fallback = true; return; }
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

    const sh = (type, src) => {
      const s = gl.createShader(type);
      gl.shaderSource(s, src); gl.compileShader(s);
      return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null;
    };
    const vs = sh(gl.VERTEX_SHADER, VERT), fs = sh(gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) { fallback = true; return; }
    const prog = gl.createProgram();
    gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog); gl.useProgram(prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 3,-1, -1,3]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(prog, 'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    const uRes = gl.getUniformLocation(prog, 'res');
    const uT = gl.getUniformLocation(prog, 't');
    const uM = gl.getUniformLocation(prog, 'mouse');

    let mx = .5, my = .5, cx = .5, cy = .5;
    const onMove = e => { mx = e.clientX / innerWidth; my = 1 - e.clientY / innerHeight; };
    addEventListener('pointermove', onMove, { passive: true });

    const dpr = Math.min(devicePixelRatio, 1.25);
    const resize = () => {
      canvas.width = innerWidth * dpr * .66;  // 降采样,模糊渐变不需要全分辨率
      canvas.height = innerHeight * dpr * .66;
      gl.viewport(0, 0, canvas.width, canvas.height);
    };
    resize();
    addEventListener('resize', resize);

    let raf, start = performance.now();
    const draw = () => {
      cx += (mx - cx) * .04; cy += (my - cy) * .04;
      gl.uniform2f(uRes, canvas.width, canvas.height);
      gl.uniform1f(uT, reduced ? 0 : (performance.now() - start) / 1000);
      gl.uniform2f(uM, cx, cy);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      raf = requestAnimationFrame(draw);
    };
    draw();
    const onVis = () => document.hidden ? cancelAnimationFrame(raf) : draw();
    document.addEventListener('visibilitychange', onVis);

    return () => {
      cancelAnimationFrame(raf);
      removeEventListener('pointermove', onMove);
      removeEventListener('resize', resize);
      document.removeEventListener('visibilitychange', onVis);
    };
  });
</script>

{#if fallback}
  <div class="aurora-fallback"><span class="b1"></span><span class="b2"></span><span class="b3"></span></div>
{:else}
  <canvas bind:this={canvas} class="shader-bg" aria-hidden="true"></canvas>
{/if}

<style>
  .shader-bg {
    position: fixed; inset: 0; z-index: -1;
    width: 100vw; height: 100vh;
  }
  .aurora-fallback { position: fixed; inset: 0; z-index: -1; overflow: hidden; }
  .aurora-fallback span { position: absolute; border-radius: 50%; filter: blur(100px); opacity: .42; animation: drift 30s ease-in-out infinite alternate; }
  .b1 { width: 46vw; height: 46vw; left: -14vw; top: -12vw; background: radial-gradient(circle, oklch(0.74 0.13 42), transparent 68%); }
  .b2 { width: 42vw; height: 42vw; right: -12vw; top: -8vw; background: radial-gradient(circle, oklch(0.66 0.12 258), transparent 68%); animation-delay: -10s; }
  .b3 { width: 36vw; height: 36vw; left: 30vw; top: 46vh; background: radial-gradient(circle, oklch(0.6 0.14 312), transparent 68%); opacity: .26; animation-delay: -20s; }
  @keyframes drift { from { transform: translate3d(0,0,0) scale(1); } to { transform: translate3d(7vw,5vh,0) scale(1.14); } }
  @media (prefers-reduced-motion: reduce) { .aurora-fallback span { animation: none; } }
</style>
