<script setup lang="ts">
defineProps<{ stage: number }>()
const early=[[310,256],[330,238],[350,262],[323,281],[364,282]]
const upper=[[404,221],[446,178],[493,145],[548,123],[602,108]]
const lower=[[406,298],[453,344],[503,381],[555,410],[610,431]]
</script>

<template>
<svg class="state-space" viewBox="0 0 900 530" role="img" aria-label="Conceptual developmental state space">
  <defs>
    <radialGradient id="shared"><stop offset="0" stop-color="#d9e4f2" stop-opacity=".6"/><stop offset="1" stop-color="#151b22" stop-opacity="0"/></radialGradient>
    <radialGradient id="cyan"><stop offset="0" stop-color="#45c7d8" stop-opacity=".45"/><stop offset="1" stop-color="#151b22" stop-opacity="0"/></radialGradient>
    <radialGradient id="amber"><stop offset="0" stop-color="#f0b44c" stop-opacity=".45"/><stop offset="1" stop-color="#151b22" stop-opacity="0"/></radialGradient>
  </defs>
  <g v-if="stage>=2">
    <ellipse cx="335" cy="260" rx="170" ry="150" fill="url(#shared)"/><ellipse cx="625" cy="105" rx="210" ry="175" fill="url(#cyan)"/><ellipse cx="630" cy="430" rx="220" ry="185" fill="url(#amber)"/>
    <g fill="none" opacity=".45"><ellipse cx="335" cy="260" rx="75" ry="64" stroke="#9aabba"/><ellipse cx="335" cy="260" rx="118" ry="104" stroke="#758594"/><ellipse cx="625" cy="105" rx="90" ry="67" stroke="#45c7d8"/><ellipse cx="625" cy="105" rx="145" ry="112" stroke="#45c7d8"/><ellipse cx="630" cy="430" rx="92" ry="68" stroke="#f0b44c"/><ellipse cx="630" cy="430" rx="150" ry="116" stroke="#f0b44c"/></g>
  </g>
  <g class="axes"><line x1="90" y1="470" x2="835" y2="470"/><line x1="90" y1="470" x2="90" y2="55"/><text x="700" y="505">learned coordinate 1</text><text transform="translate(40 330) rotate(-90)">learned coordinate 2</text></g>
  <g v-if="stage>=3" fill="none" stroke-width="5" stroke-linecap="round"><path d="M365 244 C445 210 500 153 565 120" stroke="#45c7d8" stroke-dasharray="8 10"/><path d="M365 282 C440 315 505 388 570 420" stroke="#f0b44c" stroke-dasharray="8 10"/></g>
  <g class="samples"><circle v-for="([x,y],i) in early" :key="`e${i}`" :cx="x" :cy="y" r="11" fill="#b7c5d3"/><circle v-for="([x,y],i) in upper" :key="`u${i}`" :cx="x" :cy="y" r="11" :fill="stage>=3?'#45c7d8':'#aab7c4'"/><circle v-for="([x,y],i) in lower" :key="`l${i}`" :cx="x" :cy="y" r="11" :fill="stage>=3?'#f0b44c':'#aab7c4'"/></g>
  <g v-if="stage>=3" class="labels"><text x="205" y="210">shared early region</text><text x="640" y="78" fill="#67d5e3">later sex-associated state</text><text x="640" y="465" fill="#f3c66f">later sex-associated state</text><text x="118" y="92" class="meta">observed stage gives ordering</text><text x="118" y="119" class="meta">sex helps interpret divergence</text><text x="118" y="146" class="meta">temperature remains separate metadata</text></g>
</svg>
</template>

<style scoped>
.state-space{width:100%;height:100%}.axes line{stroke:#52606d;stroke-width:1.5}.axes text{fill:#82909e;font-size:16px}.samples circle{stroke:#eef5fb;stroke-width:2}.labels text{fill:#dce6ef;font-size:19px;font-weight:650}.labels .meta{fill:#97a5b3;font-size:16px;font-weight:450}
</style>
