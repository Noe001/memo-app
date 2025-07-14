import { Controller } from "@hotwired/stimulus"
import GroupService from "../services/group_service"

export default class extends Controller {
  static values = { groupId: String }

  connect() {
    console.debug("Group switcher controller connected")
  }

  switchToGroup(event) {
    const groupId = event.currentTarget.dataset.groupId || this.groupIdValue
    console.debug(`Switching to group: ${groupId}`)
    GroupService.switchGroup(groupId)
  }

  switchToPersonal() {
    console.debug('Switching to personal memos')
    GroupService.switchGroup()
  }
}
