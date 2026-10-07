"""Premium calculation, kept separate from the routes so it can be tested and reused."""

BASE_PREMIUM = 20.0
DEFAULT_COVERAGE = 1000.0
TYPE_FACTORS = {"dog": 1.2, "cat": 1.1}
OTHER_TYPE_FACTOR = 1.3


def calculate_monthly_premium(pet_type: str, pet_age: int) -> float:
    age_factor = 1 + (pet_age / 10)
    type_factor = TYPE_FACTORS.get(pet_type.lower(), OTHER_TYPE_FACTOR)
    return round(BASE_PREMIUM * age_factor * type_factor, 2)
