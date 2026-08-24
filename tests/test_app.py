import json

import pytest

from app import create_app


@pytest.fixture()
def client():
    application = create_app({"TESTING": True, "LOG_LEVEL": "WARNING"})
    return application.test_client()


def test_index_describes_service(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.get_json()["service"] == "aws-secure-observability-platform"
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"


def test_health_is_shallow_and_healthy(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}


def test_ready_reports_database_not_configured(client):
    response = client.get("/ready")

    assert response.status_code == 200
    assert response.get_json()["dependencies"]["database"] == "not-configured"


def test_products_can_be_listed_and_selected(client):
    all_products = client.get("/api/products")
    one_product = client.get("/api/products?id=2")
    missing_product = client.get("/api/products?id=99")

    assert all_products.status_code == 200
    assert len(all_products.get_json()["products"]) == 3
    assert one_product.get_json()["product"]["name"] == "Savings"
    assert missing_product.status_code == 404


def test_products_rejects_non_integer_id(client):
    response = client.get("/api/products?id=not-an-integer")

    assert response.status_code == 400
    assert response.get_json() == {"error": "invalid_product_id"}


def test_login_does_not_reveal_which_credential_failed(client):
    malformed = client.post("/api/login", json={"username": "demo"})
    rejected = client.post(
        "/api/login", json={"username": "demo", "password": "incorrect"}
    )

    assert malformed.status_code == 400
    assert rejected.status_code == 401
    assert rejected.get_json() == {"error": "invalid_credentials"}


def test_protected_routes_deny_anonymous_requests(client):
    assert client.get("/api/account").status_code == 401
    assert client.get("/admin").status_code == 403


def test_failure_endpoint_is_disabled_by_default(client):
    response = client.get("/api/test/error")

    assert response.status_code == 404


def test_failure_endpoint_can_be_enabled_for_controlled_experiments():
    application = create_app(
        {"TESTING": True, "ENABLE_FAILURE_ENDPOINTS": True, "LOG_LEVEL": "CRITICAL"}
    )
    response = application.test_client().get("/api/test/error")

    assert response.status_code == 500
    assert response.get_json() == {"error": "controlled_test_failure"}


def test_request_id_is_generated_and_propagated(client):
    generated = client.get("/health")
    supplied = client.get("/health", headers={"X-Request-ID": "lab-request-123"})

    assert generated.headers["X-Request-ID"]
    assert supplied.headers["X-Request-ID"] == "lab-request-123"


def test_request_log_is_structured_json():
    application = create_app({"TESTING": True, "LOG_LEVEL": "INFO"})
    formatter = application.logger.handlers[0].formatter
    record = application.logger.makeRecord(
        application.logger.name,
        20,
        __file__,
        1,
        "request_completed",
        (),
        None,
        extra={"request_id": "test-id", "status_code": 200},
    )
    payload = json.loads(formatter.format(record))

    assert payload["message"] == "request_completed"
    assert payload["request_id"] == "test-id"
    assert payload["status_code"] == 200
