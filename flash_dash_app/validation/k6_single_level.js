import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";


const targetUrl = __ENV.TARGET_URL || "http://127.0.0.1:8000/health";
const virtualUsers = Number(__ENV.VIRTUAL_USERS || 100);
const iterationsPerUser = Number(__ENV.ITERATIONS_PER_USER || 50);
const transportFailures = new Counter("transport_failures");
const unexpectedStatuses = new Counter("unexpected_statuses");

export const options = {
  scenarios: {
    stress: {
      executor: "per-vu-iterations",
      vus: virtualUsers,
      iterations: iterationsPerUser,
      maxDuration: __ENV.MAX_DURATION || "60s",
    },
  },
  discardResponseBodies: true,
  noConnectionReuse: false,
  userAgent: "Flash-Dash-Validation/1.0",
  summaryTrendStats: ["avg", "med", "p(90)", "p(95)", "p(99)", "max"],
};

export default function () {
  const response = http.get(targetUrl, {
    timeout: __ENV.REQUEST_TIMEOUT || "15s",
    tags: { concurrency: String(virtualUsers) },
  });
  const valid = check(response, {
    "status entre 200 e 299": (item) => item.status >= 200 && item.status < 300,
  });
  if (!valid) {
    if (response.status === 0) {
      transportFailures.add(1);
    } else {
      unexpectedStatuses.add(1);
    }
  }
}
