extends RefCounted
## AutoPort 0.2: native Godot implementations of selected Kuningriigid JS rules.
## Every CI run compares these functions with the current upstream JS source.

static func city_capacity(time: float, _age: int) -> int:
    return mini(12, maxi(2, 2 + int(floor(maxf(0.0, time) / (26.0 * 60.0)))))

static func settler_policy(data: Dictionary) -> Dictionary:
    var time: float = float(data.get("time", 0))
    var age: int = int(data.get("age", 0))
    var cities: int = int(data.get("cities", 0))
    var pending: int = int(data.get("pending", 0))
    var pop: float = float(data.get("pop", 0))
    var food: float = float(data.get("food", 0))
    var last_at: float = float(data.get("lastAt", 0))
    var capacity: int = city_capacity(time, age)
    var interval: float = 6.0 * 60.0 if age <= 1 else (7.0 * 60.0 if age <= 3 else 10.0 * 60.0)
    var concentrate: bool = (age == 0 and cities >= 2) or (age == 1 and cities >= 2 and pop < 30)
    var allow: bool = bool(data.get("hasSettlement", false)) and cities + pending < capacity and pending < 2 and not concentrate and time >= 10.0 * 60.0 and time - last_at >= interval and pop >= (12.0 if age == 1 else 7.0) and food >= maxf(25.0, pop * 2.2)
    return {"capacity": capacity, "allow": allow, "interval": interval}

static func army_capacity(own_cities: int, age: int, at_war: bool = false) -> int:
    return mini(44, maxi(6, 3 + own_cities * 2 + age * 2 + (7 if at_war else 0)))

static func knowledge_cost_factor(age: int) -> float:
    const FACTORS: Array[float] = [0.75, 2.8, 3.3, 3.9, 4.4, 5.0, 5.6]
    return FACTORS[clampi(age, 0, 6)]

static func knowledge_city_multiplier(count: float) -> float:
    if count <= 1.0:
        return 1.0
    return minf(1.8, 1.0 + 0.12 * sqrt(count - 1.0))

static func prosperous_town_growth(data: Dictionary) -> float:
    var age: int = int(data.get("age", 0))
    if age != 1 and age != 2:
        return 1.0
    var pop: float = float(data.get("pop", 0))
    var stock: Dictionary = data.get("stock", {})
    var market_varieties: int = int(data.get("marketVarieties", 0))
    var housing_free: float = float(data.get("housingFree", 0))
    var food: float = float(stock.get("bread", 0)) + float(stock.get("flour", 0)) * 0.85 + float(stock.get("grain", 0)) * 0.7 + float(stock.get("meat", 0)) + float(stock.get("fish", 0)) + float(stock.get("berries", 0)) + float(stock.get("vegetables", 0)) + float(stock.get("fruit", 0)) + float(stock.get("cheese", 0))
    if food < pop * 1.6 or float(stock.get("water", 0)) < pop * 1.1 or housing_free < 1.0:
        return 1.0
    return minf(2.5, (2.05 if age == 1 else 1.4) + (0.3 if market_varieties >= 2 else 0.0) + (0.12 if food >= pop * 3.0 else 0.0))

static func evaluate(name: String, data: Dictionary) -> Variant:
    match name:
        "city_capacity":
            return city_capacity(float(data.get("time", 0)), int(data.get("age", 0)))
        "settler_policy":
            return settler_policy(data)
        "army_capacity":
            return army_capacity(int(data.get("ownCities", 0)), int(data.get("age", 0)), bool(data.get("atWar", false)))
        "knowledge_cost_factor":
            return knowledge_cost_factor(int(data.get("age", 0)))
        "knowledge_city_multiplier":
            return knowledge_city_multiplier(float(data.get("n", 0)))
        "prosperous_town_growth":
            return prosperous_town_growth(data)
        _:
            push_error("Unknown AutoPort gameplay function: " + name)
            return null
