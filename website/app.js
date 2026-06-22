(function () {
  'use strict';
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---- nav background on scroll ----
  var nav = document.getElementById('nav');
  function onNav() { nav.classList.toggle('scrolled', window.scrollY > 40); }
  onNav();

  // ---- reveal on scroll ----
  var reveals = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { threshold: 0.16, rootMargin: '0px 0px -8% 0px' });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }

  // ---- pinned showcase: dawn -> dusk crossfade ----
  var showcase = document.getElementById('showcase');
  var stage = showcase ? showcase.querySelector('.stage') : null;
  var shots = showcase ? showcase.querySelectorAll('.shot') : [];
  var caps = showcase ? showcase.querySelectorAll('.cap') : [];
  var bar = document.getElementById('progressBar');
  var steps = showcase ? parseInt(showcase.getAttribute('data-steps'), 10) || 5 : 5;
  var current = -1;

  function setStep(i) {
    if (i === current) return;
    current = i;
    if (stage) stage.setAttribute('data-i', i);
    shots.forEach(function (s) { s.classList.toggle('active', +s.dataset.i === i); });
    caps.forEach(function (c) { c.classList.toggle('on', +c.dataset.i === i); });
  }

  function onShowcase() {
    if (!showcase) return;
    var rect = showcase.getBoundingClientRect();
    var range = showcase.offsetHeight - window.innerHeight;
    var p = range > 0 ? (-rect.top) / range : 0;
    p = Math.max(0, Math.min(1, p));
    var i = Math.min(steps - 1, Math.floor(p * steps));
    setStep(i);
    if (bar) bar.style.width = (p * 100).toFixed(1) + '%';
  }

  // initialise
  if (!reduce && showcase) { setStep(0); }
  else { shots.forEach(function (s) { s.classList.add('active'); }); caps.forEach(function (c) { c.classList.add('on'); }); }

  // ---- rAF-throttled scroll ----
  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () {
      onNav();
      if (!reduce) onShowcase();
      ticking = false;
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', function () { current = -1; onScroll(); }, { passive: true });
  onScroll();
})();
