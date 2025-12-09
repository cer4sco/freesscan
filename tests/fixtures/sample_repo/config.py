# Test configuration file with hardcoded secrets - BAD PRACTICE
# These are fake credentials for testing purposes

DATABASE_URL = "postgresql://admin:SuperSecret123@localhost:5432/myapp"
API_KEY = "sk_live_abcdef1234567890abcdef1234567890"
DEBUG = True
SECRET_KEY = "django-insecure-abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"

# Redis configuration
REDIS_PASSWORD = "redis_pass_12345"
CACHE_URL = "redis://:redis_pass_12345@localhost:6379/0"

# Third-party API keys
STRIPE_SECRET_KEY = "sk_test_4eC39HqLyjWDarjtT1zdp7dc"
SENDGRID_API_KEY = "SG.abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOP"
TWILIO_AUTH_TOKEN = "1234567890abcdef1234567890abcdef"
