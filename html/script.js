const app = document.getElementById('app')
const listEl = document.getElementById('list')
const searchEl = document.getElementById('search')
const closeBtn = document.getElementById('close')

let vehicles = []
let filtered = []

function render(items) {
  listEl.innerHTML = ''
  items.forEach(v => {
    const props = JSON.parse(v.vehicle || '{}')
    const name = props?.modName || props?.name || props?.model || props?.modelHash || 'Unknown'
    const card = document.createElement('div')
    card.className = 'card'
    card.innerHTML = `
      <div class="title">${name}</div>
      <div class="meta">Plate: ${v.plate || '-'}</div>
      <div class="meta">Stored: ${v.stored ? 'Yes' : 'No'}</div>
      <div class="actions"><button class="btn" data-plate="${v.plate}">SWITCH</button></div>
    `
    card.querySelector('.btn').addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/switch`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: JSON.stringify({ plate: v.plate })
      })
    })
    listEl.appendChild(card)
  })
}

window.addEventListener('message', (e) => {
  const d = e.data
  if (d?.action === 'open') {
    vehicles = d.vehicles || []
    filtered = vehicles
    render(filtered)
    app.classList.remove('hidden')
    searchEl.value = ''
    searchEl.focus()
  }
})

searchEl.addEventListener('input', () => {
  const q = searchEl.value.toLowerCase()
  filtered = vehicles.filter(v => (v.plate || '').toLowerCase().includes(q) || (v.vehicle || '').toLowerCase().includes(q))
  render(filtered)
})

closeBtn.addEventListener('click', () => {
  fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' })
  app.classList.add('hidden')
})
