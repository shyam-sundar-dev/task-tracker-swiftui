import json, sys

def n(t, style=None, data=None, children=None, **kw):
    style = kw.pop("style", style)
    d = {"type": t}
    if style: d["styleId"] = style
    if data: d["dataId"] = data
    if children is not None: d["children"] = children
    d.update(kw); return d
V=lambda s=None,c=(),**k: n("vstack",s,None,list(c),**k)
H=lambda s=None,c=(),**k: n("hstack",s,None,list(c),**k)
Z=lambda s=None,c=(),**k: n("zstack",s,None,list(c),**k)
L=lambda d,s=None: n("label",s,d)
I=lambda d,s=None: n("image",s,d)
SP={"type":"spacer"}; DV={"type":"divider"}
t=lambda x:{"text":x}; sym=lambda x:{"symbol":x}

styles = {
 # shared
 "card": {"background":"#FFFFFF","cornerRadius":20,"padding":16,"shadowRadius":10,"shadowColor":"#0000001F","fillWidth":True},
 "section": {"paddingH":16},
 "sectionTitle": {"font":"title3","weight":"bold"},
 "sectionLink": {"font":"subheadline","weight":"semibold","foreground":"#E23744"},
 "title": {"font":"headline","weight":"semibold","lineLimit":1},
 "subtitle": {"font":"subheadline","foreground":"secondary","lineLimit":2},
 "caption": {"font":"caption","foreground":"secondary","lineLimit":1},
 "captionBold": {"font":"caption","weight":"bold"},
 "pill": {"font":"caption","weight":"bold","foreground":"white","background":"#E23744","paddingH":10,"paddingV":5,"cornerRadius":12},
 "pillSoft": {"font":"caption","weight":"semibold","foreground":"#E23744","background":"#E237441A","paddingH":10,"paddingV":5,"cornerRadius":12},
 # hero
 "heroBg": {"gradient":["#FF5F6D","#FFC371"],"cornerRadius":24,"height":190,"fillWidth":True,"shadowRadius":12,"shadowColor":"#FF5F6D55"},
 "heroSymbol": {"width":140,"height":140,"foreground":"#FFFFFF33"},
 "heroContent": {"padding":20,"fillWidth":True,"frameAlignment":"leading"},
 "heroTitle": {"fontSize":28,"weight":"heavy","foreground":"white","lineLimit":2},
 "heroSub": {"font":"subheadline","foreground":"#FFFFFFDD","lineLimit":2},
 "heroCta": {"font":"subheadline","weight":"bold","foreground":"#FF5F6D","background":"white","paddingH":16,"paddingV":8,"cornerRadius":18},
 # chips
 "chip": {"font":"subheadline","weight":"medium","paddingH":14,"paddingV":8,"background":"#F2F2F7","cornerRadius":18},
 "chipIcon": {"foreground":"#E23744"},
 # restaurant
 "restoCard": {"width":220,"background":"white","cornerRadius":18,"shadowRadius":6,"shadowColor":"#0000001A"},
 "restoThumb": {"height":120,"fillWidth":True,"gradient":["#A18CD1","#FBC2EB"]},
 "restoThumbIcon": {"width":56,"height":56,"foreground":"white"},
 "restoBody": {"padding":12},
 "rating": {"font":"caption","weight":"bold","foreground":"white","background":"#24963F","paddingH":6,"paddingV":3,"cornerRadius":6},
 "offerTag": {"font":"caption2","weight":"heavy","foreground":"white","background":"#256FEF","paddingH":8,"paddingV":4,"cornerRadius":6,"uppercase":True},
 "offerTagPad": {"padding":8},
 # stats
 "statTile": {"background":"#F7F7FB","cornerRadius":16,"padding":14,"fillWidth":True,"frameAlignment":"leading"},
 "statIcon": {"font":"title2","foreground":"#6C5CE7"},
 "statValue": {"fontSize":24,"weight":"bold","design":"rounded"},
 # tracking
 "trackIcon": {"width":44,"height":44,"foreground":"white","background":"#24963F","padding":10,"cornerRadius":22},
 "trackProgress": {"foreground":"#24963F"},
 "stepDone": {"font":"caption2","weight":"semibold","foreground":"#24963F"},
 "stepTodo": {"font":"caption2","foreground":"secondary"},
 # profile
 "avatar": {"width":72,"height":72,"foreground":"#6C5CE7","background":"#6C5CE71F","padding":14,"cornerRadius":36},
 "verified": {"font":"title3","foreground":"#256FEF","background":"white","cornerRadius":12},
 "profileName": {"font":"title2","weight":"bold"},
 "statCol": {"fillWidth":True},
 "statNum": {"font":"headline","weight":"bold","design":"rounded"},
 "vDivider": {"width":1,"height":32,"background":"#E5E5EA"},
 # coupons
 "coupon": {"width":260,"gradient":["#11998E","#38EF7D"],"cornerRadius":18,"padding":16},
 "coupon2": {"width":260,"gradient":["#8E2DE2","#4A00E0"],"cornerRadius":18,"padding":16},
 "couponTitle": {"fontSize":22,"weight":"black","foreground":"white"},
 "couponSub": {"font":"caption","foreground":"#FFFFFFCC","lineLimit":2},
 "couponCode": {"font":"caption","weight":"bold","design":"monospaced","foreground":"white","borderColor":"#FFFFFFAA","borderWidth":1,"paddingH":8,"paddingV":4,"cornerRadius":6},
 "couponIcon": {"width":40,"height":40,"foreground":"#FFFFFF66"},
 "oldPrice": {"font":"caption","foreground":"#FFFFFFAA","strikethrough":True},
 "newPrice": {"font":"headline","weight":"heavy","foreground":"white"},
 # products
 "productTile": {"background":"#FFF6E9","cornerRadius":14,"padding":10,"fillWidth":True},
 "productIcon": {"width":36,"height":36,"foreground":"#FF9F1C"},
 "productName": {"font":"caption","weight":"semibold","lineLimit":1,"textAlignment":"center"},
 "productPrice": {"font":"caption2","foreground":"secondary"},
 # stories
 "storyRing": {"width":68,"height":68,"gradient":["#F58529","#DD2A7B","#8134AF"],"cornerRadius":34},
 "storyInner": {"width":60,"height":60,"background":"white","cornerRadius":30,"padding":14,"foreground":"#333333"},
 "storyName": {"font":"caption2","lineLimit":1,"width":70,"textAlignment":"center"},
 # articles
 "articleThumb": {"width":64,"height":64,"gradient":["#4FACFE","#00F2FE"],"cornerRadius":12},
 "articleIcon": {"width":28,"height":28,"foreground":"white"},
 "articleTitle": {"font":"subheadline","weight":"semibold","lineLimit":2},
 # pricing
 "plan": {"fillWidth":True,"background":"#F7F7FB","cornerRadius":16,"padding":12},
 "planHot": {"fillWidth":True,"gradient":["#FC466B","#3F5EFB"],"cornerRadius":16,"padding":12,"foreground":"white","shadowRadius":8,"shadowColor":"#3F5EFB55"},
 "planName": {"font":"caption","weight":"bold","uppercase":True},
 "planPrice": {"fontSize":22,"weight":"heavy","design":"rounded"},
 "planFeature": {"font":"caption2","lineLimit":1},
 "check": {"font":"caption2"},
 # weather
 "weatherBg": {"gradient":["#2980B9","#6DD5FA"],"cornerRadius":24,"padding":18,"fillWidth":True,"foreground":"white"},
 "temp": {"fontSize":56,"weight":"thin","design":"rounded"},
 "weatherIcon": {"width":64,"height":64},
 "hourTile": {"background":"#FFFFFF33","cornerRadius":14,"paddingH":12,"paddingV":10},
 "hourIcon": {"font":"title3"},
 "white": {"foreground":"white"},
 "whiteSub": {"font":"subheadline","foreground":"#FFFFFFCC"},
 # music
 "albumArt": {"width":140,"height":140,"cornerRadius":16,"gradient":["#F7971E","#FFD200"]},
 "albumArt2": {"width":140,"height":140,"cornerRadius":16,"gradient":["#00C9FF","#92FE9D"]},
 "albumIcon": {"width":48,"height":48,"foreground":"#FFFFFFCC"},
 "albumTitle": {"font":"subheadline","weight":"semibold","lineLimit":1,"width":140,"frameAlignment":"leading"},
 "albumArtist": {"font":"caption","foreground":"secondary","lineLimit":1,"width":140,"frameAlignment":"leading"},
 "playBtn": {"font":"title2","foreground":"white","background":"#1DB954","padding":4,"cornerRadius":20},
 "playPad": {"padding":8},
}

def header(title, link="See all", tid="h_title", lid="h_link"):
    return H("section",[L(tid,"sectionTitle"),SP,L(lid,"sectionLink")],alignment="bottom")

import random
rng = random.Random(42)
styles["scrollBox"] = {"height":300,"fillWidth":True}
styles["rowSep"] = {"paddingV":6}
styles["hourTile"]["width"] = 64

pick = rng.choice
def ri(a,b): return rng.randint(a,b)

FOOD = ["fork.knife","fish.fill","leaf.fill","flame.fill","carrot.fill","cup.and.saucer.fill","birthday.cake.fill","takeoutbag.and.cup.and.straw.fill","wineglass.fill","mug.fill","popcorn.fill","frying.pan.fill"]
NAMES = ["Burger Barn","Sushi Zen","Pasta Street","Green Bowl","Taco Loco","Biryani Blues","Dosa Plaza","Wok Express","Pizza Hub","Momo Point","Kebab Korner","Cafe Mocha","Bao House","Curry Leaf","Smoke House"]
CITIES = ["Bengaluru","Mumbai","Delhi","Pune","Chennai","Hyderabad","Kolkata","Goa","Jaipur","Kochi"]
WORDS = ["Spicy","Fresh","Crispy","Golden","Smoky","Zesty","Cheesy","Royal","Classic","Loaded"]
DISH_PL = ["burgers","bowls","pizzas","wraps","biryanis","noodles","tacos","salads","platters","curries"]
DISH = ["Burger","Bowl","Pizza","Wrap","Biryani","Noodles","Tacos","Salad","Platter","Curry"]

# ---------- 10 reusable layouts (structure only) ----------
layouts = {}
layouts["hero"] = V("section",[Z("heroBg",[I("bgIcon","heroSymbol"),
    V("heroContent",[L("title","heroTitle"),L("sub","heroSub"),L("cta","heroCta")],spacing=8)],alignment="bottomTrailing")])
layouts["chips_h"] = n("carousel",data="chips",spacing=8,inset=16,template=H("chip",[I("icon","chipIcon"),L("name")],spacing=6))
layouts["resto_h"] = V(None,[header("x"),n("carousel",data="list",spacing=14,inset=16,template=V("restoCard",[
    Z(None,[Z("restoThumb",[I("icon","restoThumbIcon")]),V("offerTagPad",[L("offer","offerTag")])],alignment="topLeading"),
    V("restoBody",[H(None,[L("name","title"),SP,L("rating","rating")],spacing=6),L("meta","caption")],spacing=6)],spacing=0))],spacing=12)
layouts["stats_grid"] = V("section",[V("card",[L("title","sectionTitle"),n("grid",data="stats",columns=2,spacing=10,
    template=V("statTile",[I("icon","statIcon"),L("value","statValue"),L("label","caption")],spacing=4))],spacing=12)])
layouts["tracking"] = V("section",[V("card",[
    H(None,[I("icon","trackIcon"),V(None,[L("title","title"),L("sub","subtitle")],spacing=2),SP,L("eta","pill")],spacing=12),
    n("progress","trackProgress","progress"),
    H(None,[L("s0","stepDone"),SP,L("s1","stepDone"),SP,L("s2","stepDone"),SP,L("s3","stepTodo")])],spacing=14)])
layouts["stories_h"] = V(None,[header("x"),n("carousel",data="list",spacing=12,inset=16,template=V(None,[
    Z("storyRing",[I("icon","storyInner")]),L("name","storyName")],alignment="center",spacing=6))],spacing=12)
layouts["coupons_h"] = V(None,[header("x"),n("carousel",data="list",spacing=12,inset=16,template=V("coupon",[
    H(None,[V(None,[L("title","couponTitle"),L("sub","couponSub")],spacing=4),SP,I("icon","couponIcon")],alignment="top"),
    H(None,[L("code","couponCode"),SP,V(None,[L("old","oldPrice"),L("new","newPrice")],alignment="trailing",spacing=0)],alignment="bottom")],spacing=16))],spacing=12)
layouts["grocery_grid"] = V("section",[V("card",[H(None,[L("title","sectionTitle"),SP,L("badge","pill")]),
    n("grid",data="list",columns=3,spacing=10,template=V("productTile",[I("icon","productIcon"),L("name","productName"),L("price","productPrice")],alignment="center",spacing=6))],spacing=12)])
# Vertical scrollable list nested inside the cell
layouts["articles_vscroll"] = V("section",[V("card",[H(None,[L("title","sectionTitle"),SP,L("count","pillSoft")]),
    n("vlist",style="scrollBox",data="list",spacing=0,template=V("rowSep",[H(None,[Z("articleThumb",[I("icon","articleIcon")]),
        V(None,[L("title","articleTitle"),L("meta","caption")],spacing=4),SP],spacing=12)]))],spacing=12)])
layouts["weather_nested_h"] = V("section",[V("weatherBg",[
    H(None,[V(None,[L("city","title"),L("temp","temp"),L("desc","whiteSub")],spacing=0),SP,I("icon","weatherIcon")]),
    L("hint","whiteSub"),
    n("carousel",data="hours",spacing=8,template=V("hourTile",[L("h","captionBold"),I("icon","hourIcon"),L("t","captionBold")],alignment="center",spacing=6))],spacing=12)])

# ---------- data generators: 10 variants per layout ----------
def d_hero(i):
    return {"bgIcon":sym(pick(FOOD)),"title":t(f"{pick(WORDS)} {pick(DISH)}\n{pick([20,30,40,50,60])}% OFF"),
            "sub":t(f"On {ri(50,900)}+ restaurants in {pick(CITIES)}"),"cta":t(pick(["Order now","Grab deal","Explore","Claim"]))}
def d_chips(i):
    return {"chips":{"items":[{"icon":sym(pick(FOOD)),"name":t(f"{pick(WORDS)} {pick(DISH)}")} for _ in range(ri(8,15))]}}
def d_resto(i):
    return {"h_title":t(pick(["Popular near you","Top rated","New arrivals","Trending in "+pick(CITIES),"Late night"])),"h_link":t("See all"),
            "list":{"items":[{"name":t(pick(NAMES)),"rating":t(f"{rng.uniform(3.5,4.9):.1f} ★"),
              "meta":t(f"{ri(15,55)} min · ₹{ri(2,15)*100} for two"),"icon":sym(pick(FOOD)),
              "offer":t(pick(["50% off","Free delivery","₹100 off","BOGO","20% off","Flat ₹75"]))} for _ in range(ri(6,12))]}}
def d_stats(i):
    labs=[("bolt.fill","Orders"),("star.fill","Avg rating"),("indianrupeesign.circle.fill","Saved"),("clock.fill","Avg ETA"),("heart.fill","Favourites"),("flame.fill","Streak")]
    rng.shuffle(labs)
    return {"title":t(f"Your {pick(['week','month','year'])} in food"),
            "stats":{"items":[{"icon":sym(a),"value":t(str(ri(1,2000))),"label":t(b)} for a,b in labs[:pick([2,4,6])]]}}
def d_tracking(i):
    return {"icon":sym(pick(["bicycle","car.fill","scooter","figure.walk"])),"title":t(f"{pick(['Rahul','Priya','Arjun','Neha','Vikram'])} is on the way"),
            "sub":t(f"{pick(NAMES)} · {ri(1,6)} items"),"eta":t(f"{ri(2,30)} min"),"progress":{"value":round(rng.uniform(0.1,0.95),2)},
            "s0":t("Placed"),"s1":t("Cooking"),"s2":t("On the way"),"s3":t("Delivered")}
def d_stories(i):
    return {"h_title":t("Stories"),"h_link":t("Watch"),"list":{"items":[{"icon":sym(pick(FOOD)),"name":t(pick(NAMES))} for _ in range(ri(8,16))]}}
def d_coupons(i):
    return {"h_title":t(pick(["Offers for you","Bank offers","Today only"])),"h_link":t("All offers"),
            "list":{"items":[{"title":t(pick(["Flat ₹150","60% OFF","Free Dessert","2× Points","₹99 Meal"])),"sub":t(f"On orders above ₹{ri(2,9)*100}"),
              "code":t(pick(["ZOMSAVE","WELCOME60","SWEET","GOLD2X","TRYNEW"])),"old":t(f"₹{ri(3,9)*100}"),"new":t(f"₹{ri(1,3)*100}"),
              "icon":sym("ticket.fill")} for _ in range(ri(4,10))]}}
def d_grocery(i):
    return {"title":t(pick(["Instamart picks","Fresh today","Pantry restock","Snack time"])),"badge":t(f"{ri(8,20)} min"),
            "list":{"items":[{"icon":sym(pick(FOOD)),"name":t(f"{pick(WORDS)} {pick(DISH)}"),"price":t(f"₹{ri(20,900)}")} for _ in range(pick([3,6,9,12]))]}}
def d_articles(i):
    k=ri(10,25)
    return {"title":t("Reads for you"),"count":t(f"{k} new"),
            "list":{"items":[{"icon":sym(pick(["newspaper.fill","chart.line.uptrend.xyaxis","heart.text.square.fill","book.fill","lightbulb.fill"])),
              "title":t(f"{pick(WORDS)} {pick(DISH_PL)} are taking over {pick(CITIES)}"),
              "meta":t(f"{pick(['Food Biz','Tech','Lifestyle','Trends'])} · {ri(2,9)} min read")} for _ in range(k)]}}
WX=["sun.max.fill","cloud.sun.fill","cloud.fill","cloud.drizzle.fill","cloud.rain.fill","cloud.bolt.rain.fill","cloud.moon.fill"]
def d_weather(i):
    base=ri(18,34)
    return {"city":t(pick(CITIES)),"temp":t(f"{base}°"),"desc":t(f"H {base+3}° L {base-6}°"),"icon":sym(pick(WX)),
            "hint":t(pick(["Rain expected later — order early!","Perfect evening for chai","Hot day, try something cold"])),
            "hours":{"items":[{"h":t(f"{(h%12) or 12} {'AM' if h<12 else 'PM'}"),"icon":sym(pick(WX)),"t":t(f"{base+ri(-4,3)}°")} for h in range(ri(8,24))]}}

gens = {"hero":d_hero,"chips_h":d_chips,"resto_h":d_resto,"stats_grid":d_stats,"tracking":d_tracking,"stories_h":d_stories,
        "coupons_h":d_coupons,"grocery_grid":d_grocery,"articles_vscroll":d_articles,"weather_nested_h":d_weather}
COPIES = int(sys.argv[2]) if len(sys.argv) > 2 else 1
items=[]
for c in range(COPIES):
    for lid,g in gens.items():
        for i in range(10):
            items.append({"id":f"{lid}_{c}_{i}","layoutId":lid,"data":g(i)})
rng.shuffle(items)

def walk(node):
    if "styleId" in node and node["styleId"] not in styles: sys.exit("missing style "+node["styleId"])
    for c in node.get("children",[]): walk(c)
    if "template" in node: walk(node["template"])
for l in layouts.values(): walk(l)
json.dump({"styles":styles,"layouts":layouts,"items":items}, open(sys.argv[1],"w"), ensure_ascii=False, separators=(",",":"))
print(len(layouts),"layouts,",len(items),"items")
