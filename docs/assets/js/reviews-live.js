/**
 * This script does two things, and both are optional independently:
 *
 * 1. Keeps the "Based on X Facebook reviews. Checked on Y." summary line
 *    in sync automatically. It looks for two elements by id:
 *      <span id="review-count">20</span>
 *      <span id="review-checked-date">7 September 2026</span>
 *    (already added around the count/date in reviews.html.) Every time this
 *    script runs — i.e. every time someone loads reviews.html — it fills
 *    these in with the worker's real count and its last check date, so the
 *    line always reflects the worker's last scheduled run.
 *
 * 2. Optionally renders a full grid of live reviews if you add this markup
 *    anywhere on the page:
 *
 *    <section aria-labelledby="live-reviews-heading">
 *      <h2 id="live-reviews-heading">Latest from Facebook</h2>
 *      <p>Automatically updated from our Facebook Page.</p>
 *      <div id="live-reviews" class="reviews-grid">
 *        <p>Loading the latest recommendations…</p>
 *      </div>
 *    </section>
 *
 * Update WORKER_URL below once you've deployed the worker. This file is
 * already linked from reviews.html via <script src="reviews-live.js">.
 */

const WORKER_URL = "https://balamani-reviews-worker.YOUR-SUBDOMAIN.workers.dev";

async function loadLiveReviews() {
  const container = document.getElementById("live-reviews");
  const countEl = document.getElementById("review-count");
  const dateEl = document.getElementById("review-checked-date");

  if (!container && !countEl && !dateEl) return;
  if (WORKER_URL.includes("YOUR-SUBDOMAIN")) return;

  try {
    const res = await fetch(`${WORKER_URL}/ratings`);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    const data = await res.json();

    // Keep the "Based on X reviews. Checked on Y." summary line in sync
    // with what the worker actually found, every time it runs.
    if (countEl && data.reviews && typeof data.reviews.length === "number") {
      countEl.textContent = data.reviews.length;
    }
    if (dateEl && data.checked_at) {
      dateEl.textContent = new Date(data.checked_at).toLocaleDateString(
        "en-GB",
        { day: "numeric", month: "long", year: "numeric" }
      );
    }

    if (!container) return;

    if (!data.reviews || data.reviews.length === 0) {
      container.innerHTML = "<p>No recommendations to show yet.</p>";
      return;
    }

    container.innerHTML = data.reviews
      .map((review) => {
        const name = escapeHtml(review.reviewer_name);
        const text = review.text
          ? `<blockquote><p>&ldquo;${escapeHtml(review.text)}&rdquo;</p></blockquote>`
          : "";
        return `
          <article class="chunk review-card">
            <h3>${name}</h3>
            <p class="review-recommendation">Recommends Balamani Shih Tzu</p>
            ${text}
          </article>
        `;
      })
      .join("");
  } catch (err) {
    container.innerHTML =
      "<p>Couldn't load the latest recommendations right now — see our reviews above, or visit our Facebook page directly.</p>";
    console.error("Live reviews failed to load:", err);
  }
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// The curated excerpt count is maintained in reviews.html.
loadLiveReviews();
