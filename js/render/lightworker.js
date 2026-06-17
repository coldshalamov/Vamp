/* =========================================================================
 * VAMPIRE CITY — render/lightworker.js
 * Optional OffscreenCanvas blur prep for lighting (behind ArtFlags.useLightWorker).
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  let worker = null;
  let pending = null;
  let resultCanvas = null;

  function supported() {
    return typeof OffscreenCanvas !== 'undefined' && typeof Worker !== 'undefined';
  }

  function init() {
    if (!VAMP.ArtFlags || !VAMP.ArtFlags.useLightWorker || !supported()) return false;
    try {
      const blob = new Blob([
        'self.onmessage=function(e){var d=e.data;var c=new OffscreenCanvas(d.w,d.h);var g=c.getContext("2d");' +
        'var id=g.createImageData(d.w,d.h);id.data.set(d.buf);g.putImageData(id,0,0);' +
        'for(var p=0;p<d.pass;p++){g.filter="blur("+d.radius+"px)";g.drawImage(c,0,0);}' +
        'var out=g.getImageData(0,0,d.w,d.h);self.postMessage({buf:out.data.buffer},[out.data.buffer]);};'
      ], { type: 'application/javascript' });
      worker = new Worker(URL.createObjectURL(blob));
      worker.onmessage = function (ev) {
        if (!pending) return;
        const w = pending.w, h = pending.h;
        if (!resultCanvas || resultCanvas.width !== w) resultCanvas = VAMP.Assets.makeCanvas(w, h);
        const g = resultCanvas.getContext('2d');
        const img = new ImageData(new Uint8ClampedArray(ev.data.buf), w, h);
        g.putImageData(img, 0, 0);
        if (pending.resolve) pending.resolve(resultCanvas);
        pending = null;
      };
      return true;
    } catch (e) { worker = null; return false; }
  }

  function blur(srcCanvas, radius, passes) {
    if (!worker || !srcCanvas) return Promise.resolve(srcCanvas);
    const w = srcCanvas.width, h = srcCanvas.height;
    const g = srcCanvas.getContext('2d');
    const d = g.getImageData(0, 0, w, h);
    return new Promise((resolve) => {
      pending = { w, h, resolve };
      worker.postMessage({ buf: d.data.buffer, w, h, radius: radius || 4, pass: passes || 1 }, [d.data.buffer]);
    });
  }

  VAMP.LightWorker = { init, blur, supported };
})();