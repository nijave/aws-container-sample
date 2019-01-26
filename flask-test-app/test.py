import unittest
from app import app


class TestDebugApp(unittest.TestCase):
    def setUp(self):
        app.testing = True
        self.app = app.test_client()

    def test_home_page(self):
        response = self.app.get("/")
        self.assertEqual(response.data.decode(response.charset), "Hello world")


if __name__ == "__main__":
    unittest.main()