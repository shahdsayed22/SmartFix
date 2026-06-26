'use client';
/* Icon — renders a lucide-react icon component by name.
   Usage: <Icon name="Wrench" size={20} />
   Robust: tries the exact name, then an alias map, then falls back to
   Lucide.Circle so an unknown name NEVER crashes the app. */
import * as Lucide from 'lucide-react';
import React from 'react';

// Alias map: prototype names -> candidate lucide-react export names.
// First existing candidate wins; otherwise we drop to Lucide.Circle.
const ALIASES = {
  Grid3x3:      ['Grid3x3', 'Grid2x2', 'LayoutGrid'],
  BrainCircuit: ['BrainCircuit', 'Brain'],
  SprayCan:     ['SprayCan'],
  BadgeCheck:   ['BadgeCheck'],
  Paintbrush:   ['Paintbrush', 'Paintbrush2', 'PaintBucket'],
  TriangleAlert:['TriangleAlert', 'AlertTriangle'],
  ChartPie:     ['ChartPie', 'PieChart'],
};

function resolve(name) {
  if (!name) return Lucide.Circle;
  // 1) exact export
  if (Lucide[name]) return Lucide[name];
  // 2) alias candidates
  const candidates = ALIASES[name];
  if (candidates) {
    for (const c of candidates) {
      if (Lucide[c]) return Lucide[c];
    }
  }
  // 3) never crash
  return Lucide.Circle;
}

export function Icon({ name, size = 18, strokeWidth = 2, className, style, color }) {
  const C = resolve(name);
  return React.createElement(C, { size, strokeWidth, className, style, color });
}
