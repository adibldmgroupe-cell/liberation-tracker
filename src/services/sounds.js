// ═══ Sons UI — Web Audio API (aucun fichier externe) ═══

var ctx = null
function getCtx() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)()
  return ctx
}

function tone(freq, duration, type, gain) {
  var c = getCtx()
  var o = c.createOscillator()
  var g = c.createGain()
  o.type = type || 'sine'
  o.frequency.value = freq
  g.gain.setValueAtTime(gain || 0.15, c.currentTime)
  g.gain.exponentialRampToValueAtTime(0.001, c.currentTime + duration)
  o.connect(g)
  g.connect(c.destination)
  o.start(c.currentTime)
  o.stop(c.currentTime + duration)
}

// 1. Ding positif — circuit avance, doc transmis/approuvé, AQL conforme, lot libéré
export function playPositif() {
  tone(880, 0.15, 'sine', 0.12)
  setTimeout(function() { tone(1100, 0.2, 'sine', 0.10) }, 100)
}

// 2. Pop neutre — AQL demandé, RVP déclaré, déviation clôturée
export function playNeutre() {
  tone(660, 0.12, 'sine', 0.12)
}

// 3. Alerte basse — retour document, AQL non conforme, déviation déclarée
export function playAlerte() {
  tone(440, 0.15, 'triangle', 0.15)
  setTimeout(function() { tone(330, 0.25, 'triangle', 0.12) }, 120)
}

// 4. Rappel — planning J-1
export function playRappel() {
  tone(700, 0.12, 'sine', 0.10)
  setTimeout(function() { tone(880, 0.15, 'sine', 0.10) }, 180)
}

// 5. Rappel urgent — planning Jour J / dépassé
export function playUrgent() {
  tone(800, 0.1, 'square', 0.08)
  setTimeout(function() { tone(1000, 0.1, 'square', 0.08) }, 100)
  setTimeout(function() { tone(800, 0.1, 'square', 0.08) }, 200)
}

// 6. Knock — relance AQL
export function playKnock() {
  tone(200, 0.06, 'square', 0.12)
  setTimeout(function() { tone(200, 0.06, 'square', 0.12) }, 100)
}

// Mapping event_type → son
var SOUND_MAP = {
  circuit_avance: playPositif,
  document_transmis: playPositif,
  document_approuve: playPositif,
  lot_libere: playPositif,
  aql_resultat_conforme: playPositif,
  aql_demande: playNeutre,
  rvp_declare: playNeutre,
  deviation_cloturee: playNeutre,
  da_micro_applicable: playNeutre,
  document_retourne: playAlerte,
  aql_resultat: playAlerte,
  deviation_declaree: playAlerte,
  planning_j_moins_1: playRappel,
  planning_jour_j: playUrgent,
  planning_depasse: playUrgent
}

export function playSoundForEvent(eventType) {
  var fn = SOUND_MAP[eventType]
  if (fn) fn()
  else playNeutre() // son par défaut
}
