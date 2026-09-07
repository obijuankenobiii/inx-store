let cards = [];

function escapeHtml(value) {
  return String(value || "").replace(/[&<>\"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" })[c]);
}

async function loadCards() {
  const list = document.getElementById("card-list");
  try {
    const response = await fetch("/api/plugin/study-cards/cards_json");
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || "Could not load cards");
    cards = data.cards || [];
    const unanswered = cards.filter((card) => !String(card.back || "").trim()).length;
    document.getElementById("summary").textContent = `${cards.length} card${cards.length === 1 ? "" : "s"}${unanswered ? ` · ${unanswered} unanswered` : ""}`;
    list.innerHTML = cards.length ? cards.map((card, index) => `
      <article class="card-row">
        <span class="card-label">Front</span>
        <div class="card-front">${escapeHtml(card.front || card.text || "")}</div>
        <label class="card-label" for="card-answer-${index}" style="margin-top:14px">Back / answer</label>
        <textarea class="card-answer" id="card-answer-${index}" data-card-index="${index + 1}" placeholder="Write the answer shown on the back of this card">${escapeHtml(card.back || "")}</textarea>
        <div class="card-footer">
          <div class="card-meta">${escapeHtml([card.book, card.chapter, card.tags].filter(Boolean).join(" · "))}</div>
          <button class="save-answer" type="button" data-card-index="${index + 1}">Save answer</button>
        </div>
      </article>`).join("") : '<div class="empty">No study cards yet. Select text in a book and choose “Add to study”.</div>';
    list.querySelectorAll(".save-answer").forEach((button) => {
      button.addEventListener("click", () => saveAnswer(button));
    });
  } catch (error) {
    document.getElementById("summary").textContent = "Unavailable";
    list.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

async function saveAnswer(button) {
  const index = button.dataset.cardIndex;
  const answer = document.querySelector(`.card-answer[data-card-index="${index}"]`).value;
  button.disabled = true;
  try {
    const response = await fetch("/api/plugin/study-cards/set_answer", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ index: Number(index), answer })
    });
    const data = await response.json();
    if (!response.ok || !data.ok) throw new Error(data.error || "Could not save answer");
    cards[Number(index) - 1].back = answer;
    button.textContent = "Saved";
    button.classList.add("saved");
    setTimeout(() => { button.textContent = "Save answer"; button.classList.remove("saved"); }, 1400);
    const unanswered = cards.filter((card) => !String(card.back || "").trim()).length;
    document.getElementById("summary").textContent = `${cards.length} card${cards.length === 1 ? "" : "s"}${unanswered ? ` · ${unanswered} unanswered` : ""}`;
  } catch (error) {
    button.textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

async function downloadCards(format) {
  const functionName = format === "anki" ? "export_anki" : "export_json";
  const filename = format === "anki" ? "study-cards.txt" : "study-cards.json";
  const response = await fetch(`/api/plugin/study-cards/${functionName}`);
  if (!response.ok) throw new Error("Could not export cards");
  const blob = await response.blob();
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}

loadCards();
