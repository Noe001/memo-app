import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { groupId: String }

  connect() {
    console.log("Group switcher controller connected")
  }

  switchToGroup(event) {
    const groupId = event.currentTarget.dataset.groupId || this.groupIdValue
    console.log(`Switching to group: ${groupId}`)
    fetch(`/groups/switch?group_id=${groupId}`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    }).then(response => {
      if (response.ok) {
        window.location.reload()
      } else {
        console.error('Failed to switch group')
      }
    }).catch(error => {
      console.error('Error switching group:', error)
    })
  }

  switchToPersonal() {
    console.log('Switching to personal memos')
    fetch('/groups/switch', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ group_id: null })
    }).then(response => {
      if (response.ok) {
        window.location.reload()
      } else {
        console.error('Failed to switch to personal memos')
      }
    }).catch(error => {
      console.error('Error switching to personal memos:', error)
    })
  }
}
