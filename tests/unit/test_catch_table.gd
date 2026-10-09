extends GutTest
const Table = preload("res://game/fishing/catch_table.gd")

func test_pool_boundaries_and_no_rare_at_jetty():
	assert_eq(Table.roll("jetty","day",99,0.699,0.5,0.5).get("species_id",""),"penny_perch")
	assert_eq(Table.roll("jetty","day",99,0.7,0.5,0.5).get("species_id",""),"bellgill")
	assert_eq(Table.roll("reeds","night",0,0.599,0.5,0.5).get("species_id",""),"penny_perch")
	assert_eq(Table.roll("reeds","night",0,0.6,0.5,0.5).get("species_id",""),"bellgill")
	assert_eq(Table.roll("reeds","dusk",0,0.9,0.5,0.5).get("species_id",""),"lantern_eel")
	assert_false(Table.roll("jetty","day",0,1.0,0.5,0.5).ok)
	assert_false(Table.roll("jetty","day",0,0.5,NAN,0.5).ok)

func test_dry_streak_and_trait_are_independent():
	var r: Dictionary = Table.roll("reeds","night",11,0.0,0.099,0.5)
	assert_eq(r.get("species_id",""), "lantern_eel")
	assert_eq(r.get("trait_id",""), "oversized")
	assert_eq(r.get("catch_value",0), 50)
	assert_eq(Table.roll("jetty","day",0,0.0,0.1,0.5).get("trait_id",""), "none")
	assert_eq(Table.next_streak(8,false,false),8)
	assert_eq(Table.next_streak(8,true,false),9)
	assert_eq(Table.next_streak(11,true,true),0)
