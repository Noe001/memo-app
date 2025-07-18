// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Import and register custom controllers
import SidebarController from "./sidebar_controller"
import SettingsController from "./settings_controller"
import GroupSwitcherController from "./group_switcher_controller"
import GroupCreateController from "./group_create_controller"

application.register("sidebar", SidebarController)
application.register("settings", SettingsController)
application.register("group_switcher", GroupSwitcherController)
application.register("group-create", GroupCreateController)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)
