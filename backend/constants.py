from enum import Enum

class TransactionCategory(str, Enum):
    SHOPPING = "shopping"
    BILLS = "bills"
    FOOD = "food"
    HEALTH = "health"
    RENT = "rent"
    SAVINGS = "savings"
    OTHER = "other"

# UI Display labels (Arabic)
CATEGORY_LABELS = {
    TransactionCategory.SHOPPING: "تسوق",
    TransactionCategory.BILLS: "فواتير",
    TransactionCategory.FOOD: "مطاعم",
    TransactionCategory.HEALTH: "صحة",
    TransactionCategory.RENT: "إيجار",
    TransactionCategory.SAVINGS: "ادخار",
    TransactionCategory.OTHER: "أخرى",
}

# Mapping legacy database strings to Enum keys for backward compatibility
LEGACY_CATEGORY_MAP = {
    "تسوق": TransactionCategory.SHOPPING,
    "فواتير": TransactionCategory.BILLS,
    "مطاعم": TransactionCategory.FOOD,
    "صحة": TransactionCategory.HEALTH,
    "إيجار": TransactionCategory.RENT,
    "ادخار": TransactionCategory.SAVINGS,
    "أخرى": TransactionCategory.OTHER,
}
