import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [ "name" ]

  chosen(event) {
    const file = event.currentTarget.files[0];

    if (!file) {
      this.nameTarget.textContent = "";
      this.nameTarget.classList.add("hidden");
      return;
    }

    this.nameTarget.textContent = file.name;
    this.nameTarget.classList.remove("hidden");
    this.element.closest("form").requestSubmit();
  }

  activate() {
    this.element.classList.add("border-orange-400", "bg-orange-50");
  }

  deactivate() {
    this.element.classList.remove("border-orange-400", "bg-orange-50");
  }
}
