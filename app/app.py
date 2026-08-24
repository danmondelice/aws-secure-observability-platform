"""Small production-style Flask API used by the observability lab."""

from __future__ import annotations

import json
import logging
import os
import time
import uuid
from typing import Any

from flask import Flask, Response, g, jsonify, request
from werkzeug.middleware.proxy_fix import ProxyFix


PRODUCTS = (
    {"id": 1, "name": "Checking", "category": "deposit"},
    {"id": 2, "name": "Savings", "category": "deposit"},
    {"id": 3, "name": "Personal Loan", "category": "credit"},
)


class JsonFormatter(logging.Formatter):
    """Emit one JSON object per log line for CloudWatch Logs queries."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%SZ"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for field in (
            "request_id",
            "method",
            "path",
            "status_code",
            "duration_ms",
            "remote_addr",
        ):
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = value
        return json.dumps(payload, separators=(",", ":"))


def configure_logging(app: Flask) -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    app.logger.handlers.clear()
    app.logger.addHandler(handler)
    app.logger.setLevel(app.config["LOG_LEVEL"])
    app.logger.propagate = False


def create_app(test_config: dict[str, Any] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_mapping(
        ENABLE_FAILURE_ENDPOINTS=os.getenv("ENABLE_FAILURE_ENDPOINTS", "false").lower()
        == "true",
        LOG_LEVEL=os.getenv("LOG_LEVEL", "INFO").upper(),
    )
    if test_config:
        app.config.update(test_config)

    # The application receives traffic through one ALB proxy hop in production.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)
    configure_logging(app)

    @app.before_request
    def begin_request() -> None:
        supplied_id = request.headers.get("X-Request-ID", "")
        g.request_id = supplied_id[:128] if supplied_id else str(uuid.uuid4())
        g.request_started = time.perf_counter()

    @app.after_request
    def finish_request(response: Response) -> Response:
        response.headers["X-Request-ID"] = g.request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Cache-Control"] = "no-store"
        duration_ms = round((time.perf_counter() - g.request_started) * 1000, 2)
        app.logger.info(
            "request_completed",
            extra={
                "request_id": g.request_id,
                "method": request.method,
                "path": request.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
                "remote_addr": request.remote_addr,
            },
        )
        return response

    @app.get("/")
    def index() -> tuple[Response, int]:
        return jsonify(
            service="aws-secure-observability-platform",
            status="available",
            endpoints=["/health", "/ready", "/api/products", "/api/login"],
        ), 200

    @app.get("/health")
    def health() -> tuple[Response, int]:
        # A shallow liveness check keeps ALB health independent of downstream RDS.
        return jsonify(status="healthy"), 200

    @app.get("/ready")
    def ready() -> tuple[Response, int]:
        # Database readiness will be added with the RDS integration phase.
        return jsonify(status="ready", dependencies={"database": "not-configured"}), 200

    @app.get("/api/products")
    def products() -> tuple[Response, int]:
        product_id = request.args.get("id", type=int)
        if "id" in request.args and product_id is None:
            return jsonify(error="invalid_product_id"), 400
        if product_id is None:
            return jsonify(products=PRODUCTS), 200
        product = next((item for item in PRODUCTS if item["id"] == product_id), None)
        if product is None:
            return jsonify(error="product_not_found"), 404
        return jsonify(product=product), 200

    @app.post("/api/login")
    def login() -> tuple[Response, int]:
        # This lab endpoint validates request handling; it is not an identity provider.
        body = request.get_json(silent=True) or {}
        if not isinstance(body.get("username"), str) or not isinstance(
            body.get("password"), str
        ):
            return jsonify(error="invalid_request"), 400
        return jsonify(error="invalid_credentials"), 401

    @app.get("/api/account")
    def account() -> tuple[Response, int]:
        return jsonify(error="authentication_required"), 401

    @app.get("/admin")
    def admin() -> tuple[Response, int]:
        return jsonify(error="forbidden"), 403

    @app.get("/api/test/error")
    def test_error() -> tuple[Response, int]:
        if not app.config["ENABLE_FAILURE_ENDPOINTS"]:
            return jsonify(error="not_found"), 404
        app.logger.error(
            "controlled_test_failure",
            extra={"request_id": g.request_id},
        )
        return jsonify(error="controlled_test_failure"), 500

    @app.errorhandler(404)
    def not_found(_: Exception) -> tuple[Response, int]:
        return jsonify(error="not_found"), 404

    @app.errorhandler(405)
    def method_not_allowed(_: Exception) -> tuple[Response, int]:
        return jsonify(error="method_not_allowed"), 405

    return app


app = create_app()
