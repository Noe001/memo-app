import { handleResponse } from './response_handler'

export default class GroupService {
  static switchGroup(groupId = null) {
    const body = groupId ? { group_id: groupId } : { group_id: null }
    
    return fetch('/groups/switch', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    }).then(handleResponse)
      .then(() => window.location.reload())
  }
}
