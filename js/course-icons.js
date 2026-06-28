/**
 * course-icons.js — Realistic animated SVG course icons
 * Shared across: index.html, courses.html, pamphlet.html
 */
(function (root) {
  'use strict';

  let _ic = 0;
  function uid() { return 'ci' + (++_ic); }

  /* ── Gradient backgrounds per category ──────────────────────────────── */
  const GRAD = {
    ml:       'linear-gradient(145deg,#12003a,#4c1d95,#7c3aed)',
    devops:   'linear-gradient(145deg,#1c0500,#9a3412,#ea580c)',
    cloud:    'linear-gradient(145deg,#02101f,#075985,#0ea5e9)',
    cyber:    'linear-gradient(145deg,#1a0000,#7f1d1d,#dc2626)',
    data:     'linear-gradient(145deg,#001a0f,#064e3b,#059669)',
    testing:  'linear-gradient(145deg,#1a0f00,#92400e,#d97706)',
    network:  'linear-gradient(145deg,#06091f,#1e3a8a,#2563eb)',
    linux:    'linear-gradient(145deg,#080808,#111827,#1f2937)',
    webdev:   'linear-gradient(145deg,#0d0a2e,#3730a3,#6366f1)',
    business: 'linear-gradient(145deg,#030a1e,#1d4ed8,#3b82f6)',
    comm:     'linear-gradient(145deg,#001414,#0f766e,#0d9488)',
    leader:   'linear-gradient(145deg,#1a1000,#92400e,#d97706)',
    career:   'linear-gradient(145deg,#001a0a,#065f46,#10b981)',
    ai:       'linear-gradient(145deg,#0f0a2e,#3b1d95,#6d28d9)',
    student:  'linear-gradient(145deg,#001a2e,#0f5c8a,#1d97d4)',
    default:  'linear-gradient(145deg,#12003a,#4c1d95,#7c3aed)',
  };

  /* ── Keyword → category key ──────────────────────────────────────────── */
  function getKey(title) {
    const s = (title || '').toLowerCase();
    if (/machine\s*learn|ml\b|deep\s*learn|neural|nlp|llm|gpt|gen\s*ai|generative/.test(s)) return 'ml';
    if (/\bai\b|artificial\s*intel|computer\s*vision/.test(s)) return 'ai';
    if (/devops|ci\/?cd|jenkins|kubernetes|k8s|docker|ansible|terraform|pipeline/.test(s)) return 'devops';
    if (/cloud|aws|azure|gcp|serverless|\bs3\b|\bec2\b|\blambda\b/.test(s)) return 'cloud';
    if (/cyber|security|ethical\s*hack|pentest|vapt|\bsoc\b|siem|firewall/.test(s)) return 'cyber';
    if (/data\s*sci|analytics|power\s*bi|tableau|\bsql\b|bigquery|spark|hadoop|etl|\bdata\b/.test(s)) return 'data';
    if (/\btest|qa\b|selenium|playwright|automation|jest|cypress|postman/.test(s)) return 'testing';
    if (/network|ccna|ccnp|cisco|routing|switching|\bvpn\b/.test(s)) return 'network';
    if (/linux|unix|\bbash\b|shell\s*script|sysadmin|rhel/.test(s)) return 'linux';
    if (/java\b|python|react|angular|vue|node\.?js|web\s*dev|frontend|backend|fullstack|php|spring|webinar/.test(s)) return 'webdev';
    if (/business|finance|accounting|entrepreneur|startup|\bmba\b/.test(s)) return 'business';
    if (/commun|english|speak|vocal|public\s*speak|present|languag/.test(s)) return 'comm';
    if (/lead|manag|\bhr\b|people|strategy|scrum|agile|\bpmp\b/.test(s)) return 'leader';
    if (/interview|career|\bjob\b|placement|resume/.test(s)) return 'career';
    if (/student|intern|trainee|learner|beginner|fresher/.test(s)) return 'student';
    return 'default';
  }

  /* ══════════════════════════════════════════════════════════════════════
     SVG ICON FUNCTIONS — each returns a complete animated SVG string
     ══════════════════════════════════════════════════════════════════════ */

  /* ── Machine Learning / AI — Neural Network Brain ─────────────────── */
  function svgML(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#c084fc" stop-opacity=".3"/>
    <stop offset="100%" stop-color="#7c3aed" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="${p}hub" cx="40%" cy="35%" r="65%">
    <stop offset="0%" stop-color="#e9d5ff"/>
    <stop offset="100%" stop-color="#7c3aed"/>
  </radialGradient>
  <radialGradient id="${p}node" cx="40%" cy="35%" r="70%">
    <stop offset="0%" stop-color="#d8b4fe"/>
    <stop offset="100%" stop-color="#9333ea"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="${p}soft">
    <feGaussianBlur stdDeviation="1.2" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<!-- Ambient glow -->
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)">
  <animate attributeName="r" values="28;32;28" dur="4s" repeatCount="indefinite"/>
</circle>
<!-- Outer ring connections -->
<g stroke="#7c3aed" stroke-width=".6" opacity=".4">
  <line x1="32" y1="9" x2="51" y2="20.5"/>
  <line x1="51" y1="20.5" x2="51" y2="43.5"/>
  <line x1="51" y1="43.5" x2="32" y2="55"/>
  <line x1="32" y1="55" x2="13" y2="43.5"/>
  <line x1="13" y1="43.5" x2="13" y2="20.5"/>
  <line x1="13" y1="20.5" x2="32" y2="9"/>
</g>
<!-- Hub-to-node spokes -->
<g stroke="#a855f7" stroke-width=".9" opacity=".55">
  <line x1="32" y1="32" x2="32" y2="9"/>
  <line x1="32" y1="32" x2="51" y2="20.5"/>
  <line x1="32" y1="32" x2="51" y2="43.5"/>
  <line x1="32" y1="32" x2="32" y2="55"/>
  <line x1="32" y1="32" x2="13" y2="43.5"/>
  <line x1="32" y1="32" x2="13" y2="20.5"/>
</g>
<!-- Animated data packets -->
<circle r="1.8" fill="#f3e8ff"><animate attributeName="cx" values="32;51" dur="1.4s" repeatCount="indefinite"/><animate attributeName="cy" values="32;20.5" dur="1.4s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;1;0" dur="1.4s" repeatCount="indefinite"/></circle>
<circle r="1.8" fill="#e9d5ff"><animate attributeName="cx" values="51;32" dur="1.6s" begin=".3s" repeatCount="indefinite"/><animate attributeName="cy" values="43.5;55" dur="1.6s" begin=".3s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;1;0" dur="1.6s" begin=".3s" repeatCount="indefinite"/></circle>
<circle r="1.8" fill="#f3e8ff"><animate attributeName="cx" values="32;13" dur="1.2s" begin=".7s" repeatCount="indefinite"/><animate attributeName="cy" values="32;20.5" dur="1.2s" begin=".7s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;1;0" dur="1.2s" begin=".7s" repeatCount="indefinite"/></circle>
<circle r="1.5" fill="#ddd6fe"><animate attributeName="cx" values="13;32" dur="1.8s" begin="1.1s" repeatCount="indefinite"/><animate attributeName="cy" values="43.5;55" dur="1.8s" begin="1.1s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;1;0" dur="1.8s" begin="1.1s" repeatCount="indefinite"/></circle>
<!-- Outer nodes -->
<circle cx="32" cy="9" r="4.5" fill="url(#${p}node)" filter="url(#${p}soft)"><animate attributeName="opacity" values="1;.45;1" dur="2.3s" begin="0s" repeatCount="indefinite"/></circle>
<circle cx="51" cy="20.5" r="4.5" fill="url(#${p}node)" filter="url(#${p}soft)"><animate attributeName="opacity" values=".45;1;.45" dur="1.9s" begin=".4s" repeatCount="indefinite"/></circle>
<circle cx="51" cy="43.5" r="4.5" fill="url(#${p}node)" filter="url(#${p}soft)"><animate attributeName="opacity" values="1;.45;1" dur="2.6s" begin=".8s" repeatCount="indefinite"/></circle>
<circle cx="32" cy="55" r="4.5" fill="url(#${p}node)" filter="url(#${p}soft)"><animate attributeName="opacity" values=".45;1;.45" dur="2.1s" begin="1.2s" repeatCount="indefinite"/></circle>
<circle cx="13" cy="43.5" r="4.5" fill="url(#${p}node)" filter="url(#${p}soft)"><animate attributeName="opacity" values="1;.45;1" dur="1.7s" begin="1.6s" repeatCount="indefinite"/></circle>
<circle cx="13" cy="20.5" r="4.5" fill="url(#${p}node)" filter="url(#${p}soft)"><animate attributeName="opacity" values=".45;1;.45" dur="2.4s" begin="2s" repeatCount="indefinite"/></circle>
<!-- Node inner dots -->
<circle cx="32" cy="9" r="2" fill="white" opacity=".9"/>
<circle cx="51" cy="20.5" r="2" fill="white" opacity=".9"/>
<circle cx="51" cy="43.5" r="2" fill="white" opacity=".9"/>
<circle cx="32" cy="55" r="2" fill="white" opacity=".9"/>
<circle cx="13" cy="43.5" r="2" fill="white" opacity=".9"/>
<circle cx="13" cy="20.5" r="2" fill="white" opacity=".9"/>
<!-- Central hub -->
<circle cx="32" cy="32" r="9" fill="url(#${p}hub)" filter="url(#${p}glow)">
  <animate attributeName="r" values="8;10;8" dur="2.5s" repeatCount="indefinite"/>
</circle>
<circle cx="32" cy="32" r="5.5" fill="#6d28d9"/>
<circle cx="32" cy="32" r="2.5" fill="white" opacity=".95"/>
<circle cx="30.5" cy="30.5" r="1" fill="white" opacity=".6"/>
</svg>`;
  }

  /* ── DevOps — Infinity Loop + Rotating Gear ──────────────────────────── */
  function svgDevOps(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#fde68a"/>
    <stop offset="100%" stop-color="#f97316"/>
  </linearGradient>
  <linearGradient id="${p}g2" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0%" stop-color="#fb923c"/>
    <stop offset="100%" stop-color="#ea580c"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#fb923c" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#9a3412" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)">
  <animate attributeName="r" values="28;31;28" dur="4s" repeatCount="indefinite"/>
</circle>
<!-- Infinity loop (∞) -->
<path d="M32 32 C28 22 14 18 10 26 C6 34 12 44 22 42 C28 40 32 32 32 32 C36 24 50 18 54 26 C58 34 52 44 42 42 C36 40 32 32 32 32"
  stroke="url(#${p}g1)" stroke-width="3.5" stroke-linecap="round" fill="none" filter="url(#${p}glow)">
  <animate attributeName="stroke-dasharray" values="0 200;200 0;200 0" dur="3s" repeatCount="indefinite" calcMode="spline" keySplines="0.4 0 0.6 1;0 0 1 1"/>
  <animate attributeName="stroke-opacity" values="0.7;1;0.7" dur="3s" repeatCount="indefinite"/>
</path>
<!-- Second pass of loop (trailing glow) -->
<path d="M32 32 C28 22 14 18 10 26 C6 34 12 44 22 42 C28 40 32 32 32 32 C36 24 50 18 54 26 C58 34 52 44 42 42 C36 40 32 32 32 32"
  stroke="#fb923c" stroke-width="1" stroke-linecap="round" fill="none" opacity=".3"/>
<!-- Rotating gear at center -->
<g filter="url(#${p}glow)">
  <animateTransform attributeName="transform" type="rotate" from="0 32 32" to="360 32 32" dur="8s" repeatCount="indefinite"/>
  <!-- Gear body -->
  <circle cx="32" cy="32" r="6" fill="#ea580c" stroke="#fde68a" stroke-width="1.2"/>
  <circle cx="32" cy="32" r="3" fill="#1c0800"/>
  <!-- Teeth (8 teeth) -->
  <rect x="30.5" y="22" width="3" height="4.5" rx="1" fill="#fde68a"/>
  <rect x="30.5" y="37.5" width="3" height="4.5" rx="1" fill="#fde68a"/>
  <rect x="22" y="30.5" width="4.5" height="3" rx="1" fill="#fde68a"/>
  <rect x="37.5" y="30.5" width="4.5" height="3" rx="1" fill="#fde68a"/>
  <rect x="24.8" y="24.8" width="3" height="4.5" rx="1" fill="#fb923c" transform="rotate(45 26.3 27)"/>
  <rect x="36.2" y="24.8" width="3" height="4.5" rx="1" fill="#fb923c" transform="rotate(-45 37.7 27)"/>
  <rect x="24.8" y="34.7" width="3" height="4.5" rx="1" fill="#fb923c" transform="rotate(-45 26.3 37)"/>
  <rect x="36.2" y="34.7" width="3" height="4.5" rx="1" fill="#fb923c" transform="rotate(45 37.7 37)"/>
</g>
<!-- Animated package flowing along loop (left side) -->
<circle r="3" fill="#fbbf24" stroke="#ea580c" stroke-width=".8">
  <animate attributeName="cx" values="32;22;10;18;32" dur="4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1;.4 0 .6 1;.4 0 .6 1"/>
  <animate attributeName="cy" values="32;42;32;20;32" dur="4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1;.4 0 .6 1;.4 0 .6 1"/>
</circle>
<!-- Animated package (right side, offset) -->
<circle r="2.5" fill="#fed7aa" stroke="#f97316" stroke-width=".6">
  <animate attributeName="cx" values="32;42;54;46;32" dur="4s" begin="2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1;.4 0 .6 1;.4 0 .6 1"/>
  <animate attributeName="cy" values="32;42;32;20;32" dur="4s" begin="2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1;.4 0 .6 1;.4 0 .6 1"/>
</circle>
</svg>`;
  }

  /* ── Cloud — 3D Layered Cloud + Rising Data ──────────────────────────── */
  function svgCloud(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#e0f2fe"/>
    <stop offset="100%" stop-color="#0284c7"/>
  </linearGradient>
  <linearGradient id="${p}g2" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#bae6fd"/>
    <stop offset="100%" stop-color="#0369a1"/>
  </linearGradient>
  <linearGradient id="${p}g3" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#7dd3fc"/>
    <stop offset="100%" stop-color="#075985"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="40%" r="55%">
    <stop offset="0%" stop-color="#38bdf8" stop-opacity=".3"/>
    <stop offset="100%" stop-color="#0284c7" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="${p}soft">
    <feGaussianBlur stdDeviation="1.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Cloud shadow layer -->
<ellipse cx="33" cy="46" rx="20" ry="5" fill="#0369a1" opacity=".2"/>
<!-- Main cloud body (floating) -->
<g>
  <animateTransform attributeName="transform" type="translate" values="0,0;0,-3;0,0" dur="4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
  <!-- Bottom cloud layer (darker, shadow) -->
  <path d="M48 42H18a11 11 0 010-22c.5 0 1 .03 1.5.08A11 11 0 0143 22.5a10 10 0 015 19.5z" fill="url(#${p}g3)" filter="url(#${p}soft)" opacity=".5" transform="translate(1.5,2)"/>
  <!-- Mid cloud layer -->
  <path d="M48 40H18a11 11 0 010-22c.5 0 1 .03 1.5.08A11 11 0 0143 20.5a10 10 0 015 19.5z" fill="url(#${p}g2)" opacity=".8"/>
  <!-- Top cloud (brightest) -->
  <path d="M47 38H17a11 11 0 010-22c.5 0 1 .03 1.5.08A11 11 0 0142 18.5a10 10 0 015 19.5z" fill="url(#${p}g1)" filter="url(#${p}glow)"/>
  <!-- Cloud highlight -->
  <path d="M22 22 C26 17 33 16 38 19" stroke="white" stroke-width="2" stroke-linecap="round" opacity=".45"/>
  <!-- Small fluffy bump highlight -->
  <ellipse cx="26" cy="21" rx="5" ry="3.5" fill="white" opacity=".18"/>
</g>
<!-- Animated upload arrows -->
<g fill="none" stroke="#7dd3fc" stroke-linecap="round" stroke-linejoin="round">
  <g stroke-width="2">
    <animate attributeName="opacity" values="1;0.3;1" dur="1.8s" repeatCount="indefinite"/>
    <line x1="25" y1="56" x2="25" y2="49"><animate attributeName="y1" values="58;51" dur="1.8s" repeatCount="indefinite"/><animate attributeName="y2" values="51;44" dur="1.8s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="1.8s" repeatCount="indefinite"/></line>
    <polyline points="22,51 25,48 28,51"><animate attributeName="points" values="22,53 25,50 28,53;22,46 25,43 28,46" dur="1.8s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="1.8s" repeatCount="indefinite"/></polyline>
  </g>
  <g stroke-width="2">
    <line x1="32" y1="60" x2="32" y2="53"><animate attributeName="y1" values="60;53" dur="1.8s" begin=".6s" repeatCount="indefinite"/><animate attributeName="y2" values="53;46" dur="1.8s" begin=".6s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="1.8s" begin=".6s" repeatCount="indefinite"/></line>
    <polyline points="29,53 32,50 35,53"><animate attributeName="points" values="29,55 32,52 35,55;29,48 32,45 35,48" dur="1.8s" begin=".6s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="1.8s" begin=".6s" repeatCount="indefinite"/></polyline>
  </g>
  <g stroke-width="2">
    <line x1="39" y1="56" x2="39" y2="49"><animate attributeName="y1" values="58;51" dur="1.8s" begin="1.2s" repeatCount="indefinite"/><animate attributeName="y2" values="51;44" dur="1.8s" begin="1.2s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="1.8s" begin="1.2s" repeatCount="indefinite"/></line>
    <polyline points="36,51 39,48 42,51"><animate attributeName="points" values="36,53 39,50 42,53;36,46 39,43 42,46" dur="1.8s" begin="1.2s" repeatCount="indefinite"/><animate attributeName="opacity" values="1;0" dur="1.8s" begin="1.2s" repeatCount="indefinite"/></polyline>
  </g>
</g>
</svg>`;
  }

  /* ── Cybersecurity — Shield + Scanning Beam + Lock ───────────────────── */
  function svgCyber(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#fca5a5"/>
    <stop offset="100%" stop-color="#b91c1c"/>
  </linearGradient>
  <linearGradient id="${p}scan" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#f87171" stop-opacity="0"/>
    <stop offset="45%" stop-color="#f87171" stop-opacity=".9"/>
    <stop offset="55%" stop-color="#fca5a5" stop-opacity=".9"/>
    <stop offset="100%" stop-color="#f87171" stop-opacity="0"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="40%" r="55%">
    <stop offset="0%" stop-color="#f87171" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#7f1d1d" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="3" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <clipPath id="${p}clip">
    <path d="M32 7 L55 17 L55 34 C55 47 44.5 56 32 60 C19.5 56 9 47 9 34 L9 17 Z"/>
  </clipPath>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Shield outer glow -->
<path d="M32 7 L55 17 L55 34 C55 47 44.5 56 32 60 C19.5 56 9 47 9 34 L9 17 Z"
  fill="none" stroke="#ef4444" stroke-width="1" opacity=".4" filter="url(#${p}glow)"/>
<!-- Shield body -->
<path d="M32 9 L53 18 L53 34 C53 46 43 54.5 32 58 C21 54.5 11 46 11 34 L11 18 Z"
  fill="rgba(185,28,28,.15)" stroke="url(#${p}g1)" stroke-width="1.8" filter="url(#${p}glow)"/>
<!-- Hex grid pattern on shield -->
<g clip-path="url(#${p}clip)" stroke="#ef4444" stroke-width=".7" opacity=".2" fill="none">
  <path d="M32 10 L38 14 L38 22 L32 26 L26 22 L26 14Z"/>
  <path d="M44 16 L50 20 L50 28 L44 32 L38 28 L38 20Z"/>
  <path d="M20 16 L26 20 L26 28 L20 32 L14 28 L14 20Z"/>
  <path d="M32 26 L38 30 L38 38 L32 42 L26 38 L26 30Z"/>
  <path d="M44 32 L50 36 L50 44 L44 48 L38 44 L38 36Z"/>
  <path d="M20 32 L26 36 L26 44 L20 48 L14 44 L14 36Z"/>
  <path d="M32 42 L38 46 L38 54 L32 58 L26 54 L26 46Z"/>
</g>
<!-- Red scanning beam -->
<rect x="9" y="28" width="46" height="8" fill="url(#${p}scan)" clip-path="url(#${p}clip)">
  <animate attributeName="y" values="8;52;8" dur="2.8s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
</rect>
<!-- Scan line (bright) -->
<line x1="9" y1="32" x2="55" y2="32" stroke="#fca5a5" stroke-width=".8" clip-path="url(#${p}clip)" opacity=".6">
  <animate attributeName="y1" values="8;56;8" dur="2.8s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
  <animate attributeName="y2" values="8;56;8" dur="2.8s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
</line>
<!-- Lock body -->
<rect x="25.5" y="34" width="13" height="11" rx="2.5" fill="#b91c1c" stroke="#fca5a5" stroke-width="1.2" filter="url(#${p}glow)"/>
<!-- Lock shackle -->
<path d="M28 34 L28 29.5 C28 25.5 36 25.5 36 29.5 L36 34" stroke="#fca5a5" stroke-width="2.2" stroke-linecap="round" fill="none"/>
<!-- Keyhole -->
<circle cx="32" cy="39" r="2.3" fill="#7f1d1d"/>
<rect x="31" y="40" width="2" height="3.5" rx="1" fill="#7f1d1d"/>
<circle cx="32" cy="39" r="1" fill="#fca5a5" opacity=".7"/>
</svg>`;
  }

  /* ── Data Analytics — Animated Bar Chart + Line Graph ────────────────── */
  function svgData(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}b1" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%" stop-color="#059669"/>
    <stop offset="100%" stop-color="#6ee7b7"/>
  </linearGradient>
  <linearGradient id="${p}b2" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%" stop-color="#047857"/>
    <stop offset="100%" stop-color="#34d399"/>
  </linearGradient>
  <linearGradient id="${p}b3" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%" stop-color="#065f46"/>
    <stop offset="100%" stop-color="#10b981"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#34d399" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#064e3b" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Grid lines -->
<g stroke="#065f46" stroke-width=".6" opacity=".35">
  <line x1="11" y1="50" x2="53" y2="50"/>
  <line x1="11" y1="42" x2="53" y2="42"/>
  <line x1="11" y1="34" x2="53" y2="34"/>
  <line x1="11" y1="26" x2="53" y2="26"/>
  <line x1="11" y1="18" x2="53" y2="18"/>
  <line x1="11" y1="50" x2="11" y2="16"/>
</g>
<!-- Bar 1 -->
<rect x="15" y="50" width="9" height="0" rx="2" fill="url(#${p}b3)" filter="url(#${p}glow)">
  <animate attributeName="y" values="50;26;50" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;24;0" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Bar 2 -->
<rect x="28" y="50" width="9" height="0" rx="2" fill="url(#${p}b2)" filter="url(#${p}glow)">
  <animate attributeName="y" values="50;18;50" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;32;0" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Bar 3 -->
<rect x="41" y="50" width="9" height="0" rx="2" fill="url(#${p}b1)" filter="url(#${p}glow)">
  <animate attributeName="y" values="50;22;50" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;28;0" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Bar reflections (top shine) -->
<rect x="15" y="50" width="9" height="0" rx="2" fill="white" opacity=".18">
  <animate attributeName="y" values="50;26;50" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;6;0" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<rect x="28" y="50" width="9" height="0" rx="2" fill="white" opacity=".18">
  <animate attributeName="y" values="50;18;50" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;6;0" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<rect x="41" y="50" width="9" height="0" rx="2" fill="white" opacity=".18">
  <animate attributeName="y" values="50;22;50" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;6;0" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Trend line -->
<polyline points="19.5,26 32.5,18 45.5,22" stroke="#6ee7b7" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none">
  <animate attributeName="opacity" values="0;1;1;0" dur="3.5s" repeatCount="indefinite" keyTimes="0;0.4;0.8;1"/>
</polyline>
<!-- Data point dots on line -->
<circle cx="19.5" cy="26" r="2.5" fill="#6ee7b7"><animate attributeName="opacity" values="0;1;1;0" dur="3.5s" repeatCount="indefinite" keyTimes="0;0.4;0.8;1"/></circle>
<circle cx="32.5" cy="18" r="2.5" fill="#34d399"><animate attributeName="opacity" values="0;0;1;0" dur="3.5s" begin=".2s" repeatCount="indefinite" keyTimes="0;0.4;0.8;1"/></circle>
<circle cx="45.5" cy="22" r="2.5" fill="#10b981"><animate attributeName="opacity" values="0;0;1;0" dur="3.5s" begin=".4s" repeatCount="indefinite" keyTimes="0;0.4;0.8;1"/></circle>
</svg>`;
  }

  /* ── Software Testing / QA — Magnifier + Checkmark + Bug ─────────────── */
  function svgTesting(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#fde68a"/>
    <stop offset="100%" stop-color="#d97706"/>
  </linearGradient>
  <radialGradient id="${p}lens" cx="35%" cy="35%" r="65%">
    <stop offset="0%" stop-color="#fef3c7" stop-opacity=".3"/>
    <stop offset="100%" stop-color="#92400e" stop-opacity=".08"/>
  </radialGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#fbbf24" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#92400e" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)">
  <animate attributeName="r" values="28;31;28" dur="4s" repeatCount="indefinite"/>
</circle>
<!-- Magnifier handle -->
<line x1="38" y1="38" x2="53" y2="53" stroke="url(#${p}g1)" stroke-width="5" stroke-linecap="round" filter="url(#${p}glow)"/>
<!-- Magnifier ring (outer) -->
<circle cx="26" cy="26" r="16" stroke="url(#${p}g1)" stroke-width="3.5" fill="url(#${p}lens)" filter="url(#${p}glow)">
  <animate attributeName="r" values="15.5;16.5;15.5" dur="2.5s" repeatCount="indefinite"/>
</circle>
<!-- Magnifier inner content -->
<circle cx="26" cy="26" r="12.5" fill="rgba(146,64,14,.06)"/>
<!-- Lens highlight arc -->
<path d="M19 18 C22 14 28 14 32 17" stroke="white" stroke-width="2" stroke-linecap="round" opacity=".5"/>
<!-- Animated checkmark inside lens -->
<polyline points="18,26 23,32 34,18" stroke="#4ade80" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none">
  <animate attributeName="stroke-dasharray" values="0,40;40,0;40,0;0,40" dur="3s" repeatCount="indefinite" keyTimes="0;0.4;0.8;1" calcMode="spline" keySplines=".4 0 .6 1;0 0 1 1;.4 0 .6 1"/>
  <animate attributeName="opacity" values="0;1;1;0" dur="3s" repeatCount="indefinite" keyTimes="0;0.35;0.75;1"/>
</polyline>
<!-- Bug icon (small, appears when check disappears) -->
<g transform="translate(47,18)" opacity="0">
  <animate attributeName="opacity" values="0;0;0.9;0.9;0" dur="3s" repeatCount="indefinite" keyTimes="0;0.6;0.7;0.9;1"/>
  <animateTransform attributeName="transform" type="translate" values="47,18;47,18;47,22;47,22;47,18" dur="3s" repeatCount="indefinite" keyTimes="0;0.6;0.7;0.9;1"/>
  <ellipse cx="0" cy="0" rx="4.5" ry="5.5" fill="#f87171"/>
  <circle cx="-2" cy="-2" r="1.2" fill="white"/>
  <circle cx="2" cy="-2" r="1.2" fill="white"/>
  <line x1="-4" y1="-5" x2="-1.5" y2="-2" stroke="#fecaca" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="4" y1="-5" x2="1.5" y2="-2" stroke="#fecaca" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="-6" y1="0" x2="-4.5" y2="0" stroke="#fecaca" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="6" y1="0" x2="4.5" y2="0" stroke="#fecaca" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="-5" y1="4" x2="-3.5" y2="2" stroke="#fecaca" stroke-width="1.2" stroke-linecap="round"/>
  <line x1="5" y1="4" x2="3.5" y2="2" stroke="#fecaca" stroke-width="1.2" stroke-linecap="round"/>
</g>
</svg>`;
  }

  /* ── Network — Topology Nodes + Pulse Rings ──────────────────────────── */
  function svgNetwork(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#93c5fd"/>
    <stop offset="100%" stop-color="#1d4ed8"/>
  </linearGradient>
  <radialGradient id="${p}node" cx="40%" cy="35%" r="65%">
    <stop offset="0%" stop-color="#60a5fa"/>
    <stop offset="100%" stop-color="#1e3a8a"/>
  </radialGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#60a5fa" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#1e3a8a" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Connection lines -->
<g stroke="#2563eb" stroke-width=".9" opacity=".45">
  <line x1="32" y1="32" x2="18" y2="14"/>
  <line x1="32" y1="32" x2="46" y2="14"/>
  <line x1="32" y1="32" x2="9" y2="36"/>
  <line x1="32" y1="32" x2="55" y2="36"/>
  <line x1="32" y1="32" x2="18" y2="52"/>
  <line x1="32" y1="32" x2="46" y2="52"/>
  <line x1="18" y1="14" x2="46" y2="14" stroke="#1d4ed8"/>
  <line x1="9" y1="36" x2="18" y2="52" stroke="#1d4ed8"/>
  <line x1="55" y1="36" x2="46" y2="52" stroke="#1d4ed8"/>
</g>
<!-- Pulse rings -->
<circle cx="32" cy="32" r="4" fill="none" stroke="#60a5fa" stroke-width="1.5">
  <animate attributeName="r" values="4;24" dur="2.2s" repeatCount="indefinite"/>
  <animate attributeName="stroke-opacity" values="0.9;0" dur="2.2s" repeatCount="indefinite"/>
  <animate attributeName="stroke-width" values="2;0.5" dur="2.2s" repeatCount="indefinite"/>
</circle>
<circle cx="32" cy="32" r="4" fill="none" stroke="#93c5fd" stroke-width="1.2">
  <animate attributeName="r" values="4;24" dur="2.2s" begin=".8s" repeatCount="indefinite"/>
  <animate attributeName="stroke-opacity" values="0.7;0" dur="2.2s" begin=".8s" repeatCount="indefinite"/>
</circle>
<!-- Outer nodes -->
<circle cx="18" cy="14" r="5" fill="url(#${p}node)" filter="url(#${p}glow)"><animate attributeName="opacity" values="1;.5;1" dur="2.2s" begin="0s" repeatCount="indefinite"/></circle>
<circle cx="46" cy="14" r="5" fill="url(#${p}node)" filter="url(#${p}glow)"><animate attributeName="opacity" values=".5;1;.5" dur="1.8s" begin=".4s" repeatCount="indefinite"/></circle>
<circle cx="9" cy="36" r="5" fill="url(#${p}node)" filter="url(#${p}glow)"><animate attributeName="opacity" values="1;.5;1" dur="2.5s" begin=".8s" repeatCount="indefinite"/></circle>
<circle cx="55" cy="36" r="5" fill="url(#${p}node)" filter="url(#${p}glow)"><animate attributeName="opacity" values=".5;1;.5" dur="2s" begin="1.2s" repeatCount="indefinite"/></circle>
<circle cx="18" cy="52" r="5" fill="url(#${p}node)" filter="url(#${p}glow)"><animate attributeName="opacity" values="1;.5;1" dur="1.7s" begin="1.6s" repeatCount="indefinite"/></circle>
<circle cx="46" cy="52" r="5" fill="url(#${p}node)" filter="url(#${p}glow)"><animate attributeName="opacity" values=".5;1;.5" dur="2.3s" begin="2s" repeatCount="indefinite"/></circle>
<!-- Node inner dots -->
<circle cx="18" cy="14" r="2.5" fill="white" opacity=".9"/>
<circle cx="46" cy="14" r="2.5" fill="white" opacity=".9"/>
<circle cx="9" cy="36" r="2.5" fill="white" opacity=".9"/>
<circle cx="55" cy="36" r="2.5" fill="white" opacity=".9"/>
<circle cx="18" cy="52" r="2.5" fill="white" opacity=".9"/>
<circle cx="46" cy="52" r="2.5" fill="white" opacity=".9"/>
<!-- Center router hub -->
<rect x="25" y="25" width="14" height="14" rx="4" fill="#1e3a8a" stroke="#60a5fa" stroke-width="1.5" filter="url(#${p}glow)"/>
<circle cx="32" cy="32" r="3" fill="#3b82f6"/>
<circle cx="28" cy="28.5" r="1.2" fill="#93c5fd"/>
<circle cx="36" cy="28.5" r="1.2" fill="#93c5fd"/>
<circle cx="28" cy="35.5" r="1.2" fill="#93c5fd"/>
<circle cx="36" cy="35.5" r="1.2" fill="#93c5fd"/>
</svg>`;
  }

  /* ── Linux — Terminal Window + Blinking Cursor ───────────────────────── */
  function svgLinux(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#4b5563" stop-opacity=".2"/>
    <stop offset="100%" stop-color="#111827" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="${p}soft">
    <feGaussianBlur stdDeviation="1" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Terminal window shadow -->
<rect x="10" y="13" width="46" height="40" rx="6" fill="black" opacity=".4" transform="translate(1.5,1.5)"/>
<!-- Terminal window -->
<rect x="8" y="11" width="48" height="42" rx="6" fill="#0d1117" stroke="#374151" stroke-width="1.5"/>
<!-- Title bar -->
<rect x="8" y="11" width="48" height="13" rx="6" fill="#1f2937"/>
<rect x="8" y="18" width="48" height="6" fill="#1f2937"/>
<!-- Traffic lights -->
<circle cx="17" cy="17.5" r="3" fill="#ef4444" filter="url(#${p}soft)"/>
<circle cx="25.5" cy="17.5" r="3" fill="#f59e0b" filter="url(#${p}soft)"/>
<circle cx="34" cy="17.5" r="3" fill="#22c55e" filter="url(#${p}soft)"/>
<!-- Terminal title -->
<text x="44" y="21" font-size="5.5" fill="#9ca3af" font-family="monospace" text-anchor="middle">bash</text>
<!-- Code lines -->
<g fill="none">
  <!-- Line 1: green prompt -->
  <text x="14" y="33" font-size="6" fill="#4ade80" font-family="monospace" filter="url(#${p}glow)">$ npm run build</text>
  <!-- Line 2: output -->
  <text x="14" y="40" font-size="5.5" fill="#6b7280" font-family="monospace">✓ compiled in 0.6s</text>
  <!-- Line 3: next prompt -->
  <text x="14" y="47" font-size="6" fill="#4ade80" font-family="monospace">$</text>
</g>
<!-- Blinking cursor -->
<rect x="20" y="41.5" width="5.5" height="7" rx="1" fill="#4ade80" filter="url(#${p}glow)">
  <animate attributeName="opacity" values="1;1;0;0;1" dur="1.2s" repeatCount="indefinite" keyTimes="0;0.4;0.5;0.9;1"/>
</rect>
<!-- Terminal green glow border -->
<rect x="8" y="11" width="48" height="42" rx="6" fill="none" stroke="#4ade80" stroke-width=".5" opacity=".2" filter="url(#${p}glow)"/>
</svg>`;
  }

  /* ── Web Development — Code Editor + </> Brackets ────────────────────── */
  function svgWebDev(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#a5b4fc"/>
    <stop offset="100%" stop-color="#4f46e5"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#818cf8" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#3730a3" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Monitor frame -->
<rect x="9" y="12" width="46" height="32" rx="4" fill="#1e1b4b" stroke="url(#${p}g1)" stroke-width="1.5"/>
<!-- Screen top bar -->
<rect x="9" y="12" width="46" height="8" rx="4" fill="#312e81"/>
<rect x="9" y="16" width="46" height="4" fill="#312e81"/>
<!-- Window dots -->
<circle cx="16" cy="16" r="2" fill="#ef4444"/>
<circle cx="22" cy="16" r="2" fill="#f59e0b"/>
<circle cx="28" cy="16" r="2" fill="#22c55e"/>
<!-- Monitor stand -->
<rect x="27" y="44" width="10" height="5" fill="#2e2a73"/>
<rect x="21" y="49" width="22" height="3.5" rx="2" fill="#2e2a73" stroke="url(#${p}g1)" stroke-width="1"/>
<!-- Animated left bracket < -->
<g filter="url(#${p}glow)">
  <path d="M21 34 L14 27 L21 20" stroke="url(#${p}g1)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <animateTransform attributeName="transform" type="translate" values="0,0;-2,0;0,0" dur="2.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
  </path>
  <!-- Animated right bracket > -->
  <path d="M43 34 L50 27 L43 20" stroke="url(#${p}g1)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <animateTransform attributeName="transform" type="translate" values="0,0;2,0;0,0" dur="2.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
  </path>
  <!-- Slash / -->
  <line x1="36" y1="19" x2="28" y2="35" stroke="#c7d2fe" stroke-width="2.5" stroke-linecap="round">
    <animate attributeName="opacity" values="1;0.3;1" dur="2.5s" repeatCount="indefinite"/>
  </line>
</g>
<!-- Code dots (simulated code lines) -->
<rect x="14" y="38" width="14" height="2" rx="1" fill="#4338ca" opacity=".6"/>
<rect x="31" y="38" width="8" height="2" rx="1" fill="#6366f1" opacity=".5"/>
<rect x="42" y="38" width="6" height="2" rx="1" fill="#4338ca" opacity=".4"/>
</svg>`;
  }

  /* ── Business / Finance — Rising Bar Chart + Arrow ───────────────────── */
  function svgBusiness(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}b1" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%" stop-color="#1d4ed8"/>
    <stop offset="100%" stop-color="#60a5fa"/>
  </linearGradient>
  <linearGradient id="${p}b2" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%" stop-color="#1e40af"/>
    <stop offset="100%" stop-color="#93c5fd"/>
  </linearGradient>
  <linearGradient id="${p}b3" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%" stop-color="#1e3a8a"/>
    <stop offset="100%" stop-color="#bfdbfe"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#60a5fa" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#1e3a8a" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Grid -->
<g stroke="#1e3a8a" stroke-width=".6" opacity=".35">
  <line x1="10" y1="51" x2="54" y2="51"/>
  <line x1="10" y1="43" x2="54" y2="43"/>
  <line x1="10" y1="35" x2="54" y2="35"/>
  <line x1="10" y1="27" x2="54" y2="27"/>
  <line x1="10" y1="51" x2="10" y2="14"/>
</g>
<!-- Bar 1 -->
<rect x="14" y="51" width="10" height="0" rx="2" fill="url(#${p}b3)" filter="url(#${p}glow)">
  <animate attributeName="y" values="51;35;51" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;16;0" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Bar 2 -->
<rect x="28" y="51" width="10" height="0" rx="2" fill="url(#${p}b2)" filter="url(#${p}glow)">
  <animate attributeName="y" values="51;27;51" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;24;0" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Bar 3 -->
<rect x="42" y="51" width="10" height="0" rx="2" fill="url(#${p}b1)" filter="url(#${p}glow)">
  <animate attributeName="y" values="51;18;51" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
  <animate attributeName="height" values="0;33;0" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Top shine on bars -->
<rect x="14" y="51" width="10" height="5" rx="2" fill="white" opacity=".15">
  <animate attributeName="y" values="51;35;51" dur="3.5s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<rect x="28" y="51" width="10" height="5" rx="2" fill="white" opacity=".15">
  <animate attributeName="y" values="51;27;51" dur="3.5s" begin=".2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<rect x="42" y="51" width="10" height="5" rx="2" fill="white" opacity=".15">
  <animate attributeName="y" values="51;18;51" dur="3.5s" begin=".4s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .2 1;.4 0 .2 1"/>
</rect>
<!-- Rising trend arrow -->
<polyline points="14,38 28,27 42,18" stroke="#93c5fd" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
  <animate attributeName="opacity" values="0;0;1;1;0" dur="3.5s" repeatCount="indefinite" keyTimes="0;0.35;0.5;0.85;1"/>
</polyline>
<polyline points="39,13 44,18 38,20" stroke="#93c5fd" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
  <animate attributeName="opacity" values="0;0;1;1;0" dur="3.5s" repeatCount="indefinite" keyTimes="0;0.35;0.5;0.85;1"/>
</polyline>
</svg>`;
  }

  /* ── Communication — Microphone + Sound Waves ────────────────────────── */
  function svgComm(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#5eead4"/>
    <stop offset="100%" stop-color="#0f766e"/>
  </linearGradient>
  <radialGradient id="${p}mic" cx="40%" cy="30%" r="65%">
    <stop offset="0%" stop-color="#99f6e4"/>
    <stop offset="100%" stop-color="#0d9488"/>
  </radialGradient>
  <radialGradient id="${p}bg" cx="50%" cy="50%" r="55%">
    <stop offset="0%" stop-color="#14b8a6" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#0f766e" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)">
  <animate attributeName="r" values="28;31;28" dur="4s" repeatCount="indefinite"/>
</circle>
<!-- Microphone body -->
<rect x="25.5" y="12" width="13" height="22" rx="6.5" fill="url(#${p}mic)" filter="url(#${p}glow)"/>
<rect x="25.5" y="12" width="13" height="10" rx="6.5" fill="white" opacity=".15"/>
<!-- Mic grille lines -->
<g stroke="rgba(15,118,110,.4)" stroke-width="1">
  <line x1="25.5" y1="22" x2="38.5" y2="22"/>
  <line x1="25.5" y1="26" x2="38.5" y2="26"/>
  <line x1="25.5" y1="30" x2="38.5" y2="30"/>
</g>
<!-- Stand arm -->
<path d="M20 30 C20 40 44 40 44 30" stroke="url(#${p}g1)" stroke-width="2.5" stroke-linecap="round" fill="none"/>
<line x1="32" y1="40" x2="32" y2="47" stroke="url(#${p}g1)" stroke-width="2.5" stroke-linecap="round"/>
<line x1="24" y1="47" x2="40" y2="47" stroke="url(#${p}g1)" stroke-width="2.5" stroke-linecap="round"/>
<!-- Sound waves right -->
<path d="M44 23 C48 26 48 34 44 37" stroke="#5eead4" stroke-width="2" stroke-linecap="round" fill="none">
  <animate attributeName="opacity" values="1;0.2;1" dur="1.6s" repeatCount="indefinite"/>
  <animate attributeName="d" values="M44 23 C48 26 48 34 44 37;M46 21 C51 25 51 35 46 39;M44 23 C48 26 48 34 44 37" dur="1.6s" repeatCount="indefinite"/>
</path>
<path d="M48 19 C54 23 54 37 48 41" stroke="#5eead4" stroke-width="1.5" stroke-linecap="round" fill="none" opacity=".55">
  <animate attributeName="opacity" values="0.55;0;0.55" dur="1.6s" begin=".4s" repeatCount="indefinite"/>
  <animate attributeName="d" values="M48 19 C54 23 54 37 48 41;M50 17 C57 22 57 38 50 43;M48 19 C54 23 54 37 48 41" dur="1.6s" begin=".4s" repeatCount="indefinite"/>
</path>
<!-- Sound waves left -->
<path d="M20 23 C16 26 16 34 20 37" stroke="#5eead4" stroke-width="2" stroke-linecap="round" fill="none">
  <animate attributeName="opacity" values="0.2;1;0.2" dur="1.6s" begin=".8s" repeatCount="indefinite"/>
  <animate attributeName="d" values="M20 23 C16 26 16 34 20 37;M18 21 C13 25 13 35 18 39;M20 23 C16 26 16 34 20 37" dur="1.6s" begin=".8s" repeatCount="indefinite"/>
</path>
<path d="M16 19 C10 23 10 37 16 41" stroke="#5eead4" stroke-width="1.5" stroke-linecap="round" fill="none" opacity=".55">
  <animate attributeName="opacity" values="0;0.55;0" dur="1.6s" begin="1.2s" repeatCount="indefinite"/>
</path>
</svg>`;
  }

  /* ── Leadership — Trophy + Stars ─────────────────────────────────────── */
  function svgLeader(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#fde68a"/>
    <stop offset="100%" stop-color="#b45309"/>
  </linearGradient>
  <linearGradient id="${p}g2" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#fef3c7"/>
    <stop offset="100%" stop-color="#d97706"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="45%" r="55%">
    <stop offset="0%" stop-color="#fbbf24" stop-opacity=".3"/>
    <stop offset="100%" stop-color="#92400e" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="3" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="${p}soft">
    <feGaussianBlur stdDeviation="1.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)">
  <animate attributeName="r" values="28;32;28" dur="4s" repeatCount="indefinite"/>
</circle>
<!-- Trophy base -->
<rect x="22" y="50" width="20" height="4" rx="2" fill="url(#${p}g1)"/>
<rect x="18" y="54" width="28" height="3.5" rx="1.5" fill="url(#${p}g1)"/>
<!-- Trophy stem -->
<rect x="29.5" y="45" width="5" height="6" fill="#d97706"/>
<!-- Trophy cup -->
<path d="M16 18 L16 36 C16 42 23 46 32 46 C41 46 48 42 48 36 L48 18 Z"
  fill="url(#${p}g1)" filter="url(#${p}glow)"/>
<!-- Cup highlight -->
<path d="M20 20 L20 34 C20 37 23 39 27 40" stroke="white" stroke-width="1.5" stroke-linecap="round" opacity=".35"/>
<!-- Trophy handles -->
<path d="M16 22 C9 22 7 32 14 35" stroke="url(#${p}g2)" stroke-width="3" stroke-linecap="round" fill="none" filter="url(#${p}soft)"/>
<path d="M48 22 C55 22 57 32 50 35" stroke="url(#${p}g2)" stroke-width="3" stroke-linecap="round" fill="none" filter="url(#${p}soft)"/>
<!-- Star on trophy -->
<polygon points="32,24 33.8,30 40,30 34.9,33.7 36.8,39.8 32,36 27.2,39.8 29.1,33.7 24,30 30.2,30"
  fill="#92400e" opacity=".7"/>
<!-- Sparkle stars -->
<path d="M9 11 L10.2 14.8 L14 16 L10.2 17.2 L9 21 L7.8 17.2 L4 16 L7.8 14.8 Z" fill="#fbbf24" filter="url(#${p}soft)">
  <animate attributeName="opacity" values="1;0.2;1" dur="2.2s" repeatCount="indefinite"/>
  <animate attributeName="transform" type="scale" values="1 1;1.3 1.3;1 1" dur="2.2s" repeatCount="indefinite" additive="sum"/>
</path>
<path d="M54 8 L55 11 L58 12 L55 13 L54 16 L53 13 L50 12 L53 11 Z" fill="#fde68a" filter="url(#${p}soft)">
  <animate attributeName="opacity" values="0.2;1;0.2" dur="1.8s" begin=".6s" repeatCount="indefinite"/>
</path>
<path d="M56 40 L57 43 L60 44 L57 45 L56 48 L55 45 L52 44 L55 43 Z" fill="#fef3c7" filter="url(#${p}soft)">
  <animate attributeName="opacity" values="1;0.2;1" dur="2.5s" begin="1.2s" repeatCount="indefinite"/>
</path>
<path d="M6 42 L7 44.5 L9.5 45.5 L7 46.5 L6 49 L5 46.5 L2.5 45.5 L5 44.5 Z" fill="#fbbf24" filter="url(#${p}soft)">
  <animate attributeName="opacity" values="0.2;1;0.2" dur="1.5s" begin=".3s" repeatCount="indefinite"/>
</path>
</svg>`;
  }

  /* ── Career — Rocket Launch ───────────────────────────────────────────── */
  function svgCareer(p) {
    return `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
  <linearGradient id="${p}g1" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0%" stop-color="#059669"/>
    <stop offset="100%" stop-color="#6ee7b7"/>
  </linearGradient>
  <linearGradient id="${p}flame" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#fde68a"/>
    <stop offset="40%" stop-color="#f97316"/>
    <stop offset="100%" stop-color="#ef4444" stop-opacity="0"/>
  </linearGradient>
  <radialGradient id="${p}bg" cx="50%" cy="45%" r="55%">
    <stop offset="0%" stop-color="#34d399" stop-opacity=".25"/>
    <stop offset="100%" stop-color="#065f46" stop-opacity="0"/>
  </radialGradient>
  <filter id="${p}glow">
    <feGaussianBlur stdDeviation="2.5" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>
<circle cx="32" cy="32" r="30" fill="url(#${p}bg)"/>
<!-- Twinkling stars -->
<circle cx="12" cy="13" r="1.5" fill="#a7f3d0"><animate attributeName="opacity" values="1;0.2;1" dur="2.1s" repeatCount="indefinite"/></circle>
<circle cx="52" cy="9" r="1.2" fill="#6ee7b7"><animate attributeName="opacity" values="0.2;1;0.2" dur="1.6s" begin=".5s" repeatCount="indefinite"/></circle>
<circle cx="57" cy="28" r="1.5" fill="#a7f3d0"><animate attributeName="opacity" values="1;0.3;1" dur="2.8s" begin="1s" repeatCount="indefinite"/></circle>
<circle cx="7" cy="40" r="1" fill="#6ee7b7"><animate attributeName="opacity" values="0.3;1;0.3" dur="1.9s" begin="1.5s" repeatCount="indefinite"/></circle>
<circle cx="55" cy="48" r="1.2" fill="#a7f3d0"><animate attributeName="opacity" values="1;0.2;1" dur="2.3s" begin="0.8s" repeatCount="indefinite"/></circle>
<!-- Rocket (floating animation) -->
<g>
  <animateTransform attributeName="transform" type="translate" values="0,0;0,-4;0,0" dur="3.2s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1"/>
  <!-- Exhaust trail -->
  <path d="M26 53 C27 50 32 48 32 48 C32 48 37 50 38 53 C36 51 28 51 26 53 Z" fill="url(#${p}flame)" opacity=".9">
    <animate attributeName="d" values="M26 53 C27 50 32 48 32 48 C32 48 37 50 38 53 C36 51 28 51 26 53 Z;M25 56 C27 49 32 46 32 46 C32 46 37 49 39 56 C36 51 28 51 25 56 Z;M26 53 C27 50 32 48 32 48 C32 48 37 50 38 53 C36 51 28 51 26 53 Z" dur="0.4s" repeatCount="indefinite"/>
  </path>
  <path d="M22 52 C24 47 28 47 28 47 C27 51 24 55 22 52 Z" fill="#fb923c" opacity=".5"/>
  <path d="M42 52 C40 47 36 47 36 47 C37 51 40 55 42 52 Z" fill="#fb923c" opacity=".5"/>
  <!-- Rocket body -->
  <path d="M32 6 C32 6 20 20 20 37 L20 48 L32 52 L44 48 L44 37 C44 20 32 6 32 6 Z"
    fill="url(#${p}g1)" filter="url(#${p}glow)"/>
  <!-- Body highlight -->
  <path d="M26 14 C27 11 30 9 32 8" stroke="white" stroke-width="1.5" stroke-linecap="round" opacity=".35"/>
  <!-- Porthole window -->
  <circle cx="32" cy="27" r="6" fill="#064e3b" stroke="#6ee7b7" stroke-width="2" filter="url(#${p}glow)"/>
  <circle cx="32" cy="27" r="3.5" fill="#065f46"/>
  <circle cx="30.5" cy="25.5" r="1.2" fill="#34d399" opacity=".8"/>
  <!-- Wing fins -->
  <path d="M20 40 L13 52 L20 48 Z" fill="#059669"/>
  <path d="M44 40 L51 52 L44 48 Z" fill="#059669"/>
</g>
</svg>`;
  }

  /* ── Default — same as ML ─────────────────────────────────────────────── */
  function svgDefault(p) { return svgML(p); }

  /* ── Accent colours (brightest hue per category) ────────────────────── */
  const ACCENT = {
    ml:       '#7c3aed',
    devops:   '#ea580c',
    cloud:    '#0ea5e9',
    cyber:    '#dc2626',
    data:     '#059669',
    testing:  '#d97706',
    network:  '#2563eb',
    linux:    '#6b7280',
    webdev:   '#6366f1',
    business: '#3b82f6',
    comm:     '#0d9488',
    leader:   '#d97706',
    career:   '#10b981',
    ai:       '#6d28d9',
    student:  '#1d97d4',
    default:  '#7c3aed',
  };

  /* ── AI Icon — Brain with circuit board design ──────────────────────── */
  function svgAI(id) {
    const g1=uid(),g2=uid();
    return `<svg viewBox="0 0 80 80" xmlns="http://www.w3.org/2000/svg">
    <defs><radialGradient id="${g1}" cx="50%" cy="40%"><stop offset="0%" stop-color="#a78bfa" stop-opacity=".3"/><stop offset="100%" stop-color="transparent"/></radialGradient>
    <linearGradient id="${g2}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#c084fc"/><stop offset="100%" stop-color="#7c3aed"/></linearGradient></defs>
    <circle cx="40" cy="40" r="30" fill="url(#${g1})"><animate attributeName="r" values="28;32;28" dur="3s" repeatCount="indefinite"/></circle>
    <path d="M40 18c-12 0-20 8-20 18s4 14 10 18c2 1 3 3 3 5h14c0-2 1-4 3-5 6-4 10-8 10-18s-8-18-20-18z" fill="none" stroke="url(#${g2})" stroke-width="2" stroke-linecap="round"/>
    <path d="M32 59h16M34 63h12" stroke="#a78bfa" stroke-width="1.5" stroke-linecap="round" opacity=".6"/>
    <circle cx="33" cy="35" r="2.5" fill="#c084fc"><animate attributeName="opacity" values="1;.3;1" dur="2s" repeatCount="indefinite"/></circle>
    <circle cx="47" cy="35" r="2.5" fill="#c084fc"><animate attributeName="opacity" values=".3;1;.3" dur="2s" repeatCount="indefinite"/></circle>
    <path d="M36 42c2 2 6 2 8 0" stroke="#a78bfa" stroke-width="1.5" fill="none" stroke-linecap="round"/>
    <line x1="22" y1="30" x2="15" y2="25" stroke="#7c3aed" stroke-width="1" opacity=".4"/><circle cx="15" cy="25" r="2" fill="#7c3aed" opacity=".4"/>
    <line x1="58" y1="30" x2="65" y2="25" stroke="#7c3aed" stroke-width="1" opacity=".4"/><circle cx="65" cy="25" r="2" fill="#7c3aed" opacity=".4"/>
    <line x1="22" y1="45" x2="13" y2="48" stroke="#7c3aed" stroke-width="1" opacity=".4"/><circle cx="13" cy="48" r="2" fill="#7c3aed" opacity=".4"/>
    <line x1="58" y1="45" x2="67" y2="48" stroke="#7c3aed" stroke-width="1" opacity=".4"/><circle cx="67" cy="48" r="2" fill="#7c3aed" opacity=".4"/>
    </svg>`;
  }

  /* ── Student Icon — Graduation cap design ──────────────────────────── */
  function svgStudent(id) {
    const g1=uid();
    return `<svg viewBox="0 0 80 80" xmlns="http://www.w3.org/2000/svg">
    <defs><linearGradient id="${g1}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#38bdf8"/><stop offset="100%" stop-color="#0284c7"/></linearGradient></defs>
    <polygon points="40,16 8,32 40,48 72,32" fill="url(#${g1})" opacity=".9"/>
    <polygon points="40,16 8,32 40,48 72,32" fill="none" stroke="#7dd3fc" stroke-width="1" opacity=".5"/>
    <line x1="40" y1="48" x2="40" y2="38" stroke="#38bdf8" stroke-width="1.5" opacity=".3"/>
    <path d="M22 36v14c0 6 8 10 18 10s18-4 18-10V36" fill="none" stroke="#38bdf8" stroke-width="1.8" stroke-linecap="round">
      <animate attributeName="stroke-opacity" values=".6;1;.6" dur="3s" repeatCount="indefinite"/>
    </path>
    <line x1="64" y1="32" x2="64" y2="56" stroke="#0ea5e9" stroke-width="1.5"/>
    <circle cx="64" cy="58" r="2.5" fill="#0ea5e9"><animate attributeName="r" values="2;3;2" dur="2s" repeatCount="indefinite"/></circle>
    <circle cx="40" cy="32" r="3" fill="#7dd3fc" opacity=".3"><animate attributeName="opacity" values=".2;.5;.2" dur="2.5s" repeatCount="indefinite"/></circle>
    </svg>`;
  }

  /* ── Icon function map ────────────────────────────────────────────────── */
  const SVGS = {
    ml: svgML, devops: svgDevOps, cloud: svgCloud, cyber: svgCyber,
    data: svgData, testing: svgTesting, network: svgNetwork, linux: svgLinux,
    webdev: svgWebDev, business: svgBusiness, comm: svgComm,
    leader: svgLeader, career: svgCareer, ai: svgAI, student: svgStudent,
    default: svgDefault,
  };

  /* ── Public API ───────────────────────────────────────────────────────── */
  function getInfo(titleOrKey) {
    const key = SVGS[titleOrKey] ? titleOrKey : getKey(titleOrKey);
    const id  = uid();
    return {
      key,
      svg:      (SVGS[key] || SVGS.default)(id),
      gradient: GRAD[key]  || GRAD.default,
      accent:   ACCENT[key] || ACCENT.default,
    };
  }

  root.CourseIcons = {
    getKey,
    getInfo,
    getGradient: function(title) { return GRAD[getKey(title)] || GRAD.default; },
  };

})(window);
