def calculate_premium(pet_type, breed, age, zip_code):
    """
    Calculate insurance premium based on pet details
    This is a simplified version - you'll want to make this more sophisticated
    """
    base_rate = 25  # Base monthly premium
    
    # Age factor
    if age < 3:
        age_factor = 1.0
    elif age < 7:
        age_factor = 1.3
    else:
        age_factor = 1.8
    
    # Breed factor (simplified)
    high_risk_breeds = ['bulldog', 'pug', 'persian', 'maine coon']
    breed_factor = 1.5 if breed.lower() in high_risk_breeds else 1.0
    
    # Pet type factor
    type_factor = 1.2 if pet_type.lower() == 'dog' else 1.0
    
    monthly_premium = base_rate * age_factor * breed_factor * type_factor
    
    return round(monthly_premium, 2)