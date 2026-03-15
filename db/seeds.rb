# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

puts "Seeding sensitivity categories..."

CATEGORIES = [
  { name: "Histamine", slug: "histamine", description: "Found in fermented foods, aged cheeses, leftovers, and alcohol. Triggers via DAO enzyme pathway." },
  { name: "FODMAP", slug: "fodmap", description: "Fermentable carbohydrates including onion, garlic, wheat, and legumes. Gut fermentation triggers." },
  { name: "Salicylate", slug: "salicylate", description: "Natural preservatives in many fruits, vegetables, and spices — often missed because foods seem healthy." },
  { name: "Oxalate", slug: "oxalate", description: "Found in spinach, nuts, chocolate, and beets. Common in clean eating foods." },
  { name: "Lectin", slug: "lectin", description: "Proteins in beans, grains, and nightshades. Relevant for autoimmune presentations." },
  { name: "Glutamate", slug: "glutamate", description: "Naturally high in tomatoes, parmesan, soy sauce, and mushrooms. Associated with neurological symptoms." },
  { name: "Capsaicin", slug: "capsaicin", description: "All peppers including bell peppers. A gut motility trigger." }
].freeze

CATEGORIES.each do |attrs|
  FoodSensitivityCategory.find_or_create_by!(slug: attrs[:slug]) do |c|
    c.name = attrs[:name]
    c.description = attrs[:description]
  end
end

puts "Seeding symptom types..."

SYMPTOM_TYPES = [
  { name: "Bloating",           slug: "bloating",          category: "gut" },
  { name: "Cramping",           slug: "cramping",          category: "gut" },
  { name: "Diarrhea",           slug: "diarrhea",          category: "gut" },
  { name: "Constipation",       slug: "constipation",      category: "gut" },
  { name: "Headache",           slug: "headache",          category: "systemic" },
  { name: "Migraine",           slug: "migraine",          category: "systemic" },
  { name: "Fatigue",            slug: "fatigue",           category: "systemic" },
  { name: "Brain Fog",          slug: "brain_fog",         category: "systemic" },
  { name: "Skin Rash",          slug: "skin_rash",         category: "systemic" },
  { name: "Hives",              slug: "hives",             category: "systemic" },
  { name: "Nasal Congestion",   slug: "nasal_congestion",  category: "systemic" },
  { name: "Joint Pain",         slug: "joint_pain",        category: "systemic" }
].freeze

SYMPTOM_TYPES.each do |attrs|
  SymptomType.find_or_create_by!(slug: attrs[:slug]) do |st|
    st.name = attrs[:name]
    st.category = attrs[:category]
  end
end

puts "Seeding foods..."

# Helper to find category
def cat(slug)
  FoodSensitivityCategory.find_by!(slug: slug)
end

# Each food: { name:, memberships: [[category_slug, severity]] }
FOODS = [
  # Histamine-primary
  { name: "Red Wine",            memberships: [["histamine", :high]] },
  { name: "Sauerkraut",          memberships: [["histamine", :high]] },
  { name: "Sardines",            memberships: [["histamine", :high]] },
  { name: "Smoked Salmon",       memberships: [["histamine", :high]] },
  { name: "Kefir",               memberships: [["histamine", :high]] },
  { name: "Canned Tuna",         memberships: [["histamine", :medium]] },
  { name: "Yogurt",              memberships: [["histamine", :medium]] },
  { name: "Vinegar",             memberships: [["histamine", :medium]] },

  # Multi-category: histamine + others
  { name: "Aged Cheddar",        memberships: [["histamine", :high],   ["glutamate", :high]] },
  { name: "Parmesan Cheese",     memberships: [["histamine", :high],   ["glutamate", :high]] },
  { name: "Miso Paste",          memberships: [["histamine", :high],   ["glutamate", :high], ["fodmap", :medium]] },
  { name: "Avocado",             memberships: [["histamine", :high],   ["salicylate", :medium]] },
  { name: "Spinach",             memberships: [["histamine", :medium], ["oxalate", :high], ["salicylate", :medium]] },
  { name: "Tomatoes",            memberships: [["histamine", :medium], ["glutamate", :high], ["salicylate", :medium], ["lectin", :high]] },
  { name: "Cocoa Powder",        memberships: [["histamine", :medium], ["oxalate", :high]] },
  { name: "Strawberries",        memberships: [["histamine", :medium], ["salicylate", :high]] },
  { name: "Raspberries",         memberships: [["histamine", :medium], ["salicylate", :high]] },
  { name: "Walnuts",             memberships: [["histamine", :low],    ["oxalate", :high]] },
  { name: "Soy Sauce",           memberships: [["glutamate", :high],   ["histamine", :medium]] },

  # FODMAP-primary
  { name: "Garlic",              memberships: [["fodmap", :high]] },
  { name: "Cauliflower",         memberships: [["fodmap", :high]] },
  { name: "Asparagus",           memberships: [["fodmap", :medium]] },

  # Multi-category: FODMAP + others
  { name: "Onion",               memberships: [["fodmap", :high],   ["glutamate", :medium]] },
  { name: "Wheat Bread",         memberships: [["fodmap", :high],   ["lectin", :high]] },
  { name: "Kidney Beans",        memberships: [["fodmap", :high],   ["lectin", :high], ["oxalate", :medium]] },
  { name: "Lentils",             memberships: [["fodmap", :medium], ["lectin", :medium]] },
  { name: "Chickpeas",           memberships: [["fodmap", :high],   ["lectin", :high]] },
  { name: "Peas",                memberships: [["fodmap", :medium], ["lectin", :medium]] },
  { name: "Mushrooms",           memberships: [["fodmap", :high],   ["glutamate", :high]] },
  { name: "Apples",              memberships: [["fodmap", :medium], ["salicylate", :high]] },
  { name: "Soybeans",            memberships: [["fodmap", :high],   ["lectin", :high]] },

  # Salicylate-primary
  { name: "Blueberries",         memberships: [["salicylate", :high]] },
  { name: "Broccoli",            memberships: [["salicylate", :high]] },
  { name: "Oregano",             memberships: [["salicylate", :high]] },
  { name: "Cucumber",            memberships: [["salicylate", :low]] },
  { name: "Zucchini",            memberships: [["salicylate", :low]] },
  { name: "Almonds",             memberships: [["salicylate", :high], ["oxalate", :medium]] },
  { name: "Curry Powder",        memberships: [["salicylate", :high], ["capsaicin", :medium]] },
  { name: "Chili Peppers",       memberships: [["capsaicin", :high],  ["salicylate", :high]] },
  { name: "Cayenne Pepper",      memberships: [["capsaicin", :high],  ["salicylate", :high]] },
  { name: "Paprika",             memberships: [["capsaicin", :medium], ["salicylate", :high]] },

  # Oxalate-primary
  { name: "Beets",               memberships: [["oxalate", :high]] },
  { name: "Rhubarb",             memberships: [["oxalate", :high]] },
  { name: "Brown Rice",          memberships: [["oxalate", :low]] },
  { name: "Sweet Potatoes",      memberships: [["oxalate", :low],   ["lectin", :medium]] },
  { name: "Peanuts",             memberships: [["oxalate", :medium], ["lectin", :high]] },

  # Lectin-primary
  { name: "Bell Peppers",        memberships: [["lectin", :high],   ["capsaicin", :high]] },
  { name: "Corn",                memberships: [["lectin", :medium]] },

  # Glutamate-primary
  { name: "Greek Yogurt",        memberships: [["histamine", :medium]] },

  # Capsaicin-primary
  { name: "Jalapeños",           memberships: [["capsaicin", :high]] }
].freeze

FOODS.each do |attrs|
  food = Food.find_or_create_by!(name: attrs[:name])

  attrs[:memberships].each do |category_slug, severity|
    category = cat(category_slug)
    FoodCategoryMembership.find_or_create_by!(food: food, food_sensitivity_category: category) do |m|
      m.severity = severity
    end
  end

  # Create a canonical ingredient for each food (for manual entry support)
  ingredient = Ingredient.find_or_create_by!(canonical_name: attrs[:name].downcase) do |i|
    i.name = attrs[:name]
  end
  IngredientFoodMapping.find_or_create_by!(ingredient: ingredient, food: food)
end

puts "Done. Seeded:"
puts "  #{FoodSensitivityCategory.count} sensitivity categories"
puts "  #{SymptomType.count} symptom types"
puts "  #{Food.count} foods"
puts "  #{FoodCategoryMembership.count} food-category memberships"
puts "  #{Ingredient.count} ingredients"
