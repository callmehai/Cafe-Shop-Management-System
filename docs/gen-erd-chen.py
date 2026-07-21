# -*- coding: utf-8 -*-
"""Sinh ERD Chen notation cho CSMS dưới dạng .drawio.

Bố cục dạng lưới: mỗi quan hệ nằm giữa 2 thực thể, cạnh vẽ bằng tọa độ tuyệt đối
(sourcePoint/targetPoint) để draw.io CLI render chắc chắn.
"""
EW, EH = 190, 70      # entity
RW, RH = 150, 86      # relationship diamond

entities = {}
rels = {}
edges = []

def E(eid, label, cx, cy, grey=False):
    entities[eid] = (label, cx, cy, grey)

def R(rid, label, cx, cy):
    rels[rid] = (label, cx, cy)

def L(a, b, card, side_a=None, side_b=None):
    """Nối a-b, `card` là nhãn đặt gần đầu a."""
    edges.append((a, b, card, side_a, side_b))

# ---------- layout (cx, cy = tâm) ----------
# Cột 1: 140 | Cột 2: 480 | Cột 3: 820 | Cột 4: 1160 | Cột 5: 1500
E("User",      "User",                140, 90)
E("Table",     "Table",               820, 90)
E("Category",  "Category",           1500, 90)

R("creates",   "creates",             480, 90)
R("classifies","classifies",         1500, 250)

E("Order",     "Order",               820, 410)
E("Product",   "Product",            1500, 410)
E("Customer",  "Customer",            140, 410)

R("servedAt",  "served at",           820, 250)
R("placedBy",  "placed by",           480, 410)
R("orderedAs", "ordered as",         1500, 570)

E("OrderItem", "OrderItem",          1160, 730)
E("Payment",   "Payment",             480, 730)

R("containsIt","contains",            990, 570)
R("paidBy",    "paid by",             650, 570)

E("Loyalty",   "Loyalty&#10;Transaction", 140, 1050)
R("generates", "generates",           480, 900)
R("earns",     "earns /&#10;redeems",  140, 730)
R("processes", "processes",            140, 570)

E("ProdIng",   "Product&#10;Ingredient", 1500, 890)
E("Ingredient","Ingredient",         1500, 1210)
R("hasRecipe", "has&#10;recipe",      1500, 730)
R("usedIn",    "used in",             1500, 1050)

# Kho ở hàng dưới cùng, chạy từ trái sang phải:
# User -(raises)- PurchaseOrder -(contains)- StockIn -(received as)- Ingredient
E("PurchaseOrder","Purchase&#10;Order", 480, 1210)
E("StockIn",   "StockIn",             990, 1210)
R("raises",    "raises",               140, 1210)
R("containsSt","contains",             735, 1210)
R("receivedAs","received&#10;as",     1245, 1210)

E("AuditLog",  "AuditLog",            140, 1420, grey=True)

# ---------- edges: (from, to, cardinality gần from) ----------
L("User", "creates", "1, 1")
L("creates", "Order", "N, 0")

L("Table", "servedAt", "1, 0")
L("servedAt", "Order", "N, 0")

L("Customer", "placedBy", "1, 0")
L("placedBy", "Order", "N, 0")

L("Category", "classifies", "1, 1")
L("classifies", "Product", "N, 0")

L("Order", "containsIt", "1, 1")
L("containsIt", "OrderItem", "N, 1")

L("Product", "orderedAs", "1, 1")
L("orderedAs", "OrderItem", "N, 0")

L("Order", "paidBy", "1, 1")
L("paidBy", "Payment", "1, 0")

L("User", "processes", "1, 1")
L("processes", "Payment", "N, 0")

L("Customer", "earns", "1, 1")
L("earns", "Loyalty", "N, 0")

L("Payment", "generates", "1, 1")
L("generates", "Loyalty", "N, 0")

L("Product", "hasRecipe", "1, 1")
L("hasRecipe", "ProdIng", "N, 0")

L("Ingredient", "usedIn", "1, 1")
L("usedIn", "ProdIng", "N, 0")

L("Ingredient", "receivedAs", "1, 1")
L("receivedAs", "StockIn", "N, 0")

L("User", "raises", "1, 1")
L("raises", "PurchaseOrder", "N, 0")

L("PurchaseOrder", "containsSt", "1, 1")
L("containsSt", "StockIn", "N, 1")


def center(nid):
    if nid in entities:
        _, cx, cy, _ = entities[nid]
    else:
        _, cx, cy = rels[nid]
    return cx, cy


def box(nid):
    if nid in entities:
        return EW, EH
    return RW, RH


def anchor(a, b):
    """Điểm ra khỏi hộp a về phía b — cắt theo cạnh gần nhất."""
    ax, ay = center(a); bx, by = center(b)
    aw, ah = box(a)
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return ax, ay
    # so sánh tỉ lệ để biết cắt cạnh dọc hay ngang
    if abs(dx) * ah >= abs(dy) * aw:
        sx = aw / 2 if dx > 0 else -aw / 2
        return ax + sx, ay + (dy * (aw / 2) / abs(dx) if dx else 0)
    sy = ah / 2 if dy > 0 else -ah / 2
    return ax + (dx * (ah / 2) / abs(dy) if dy else 0), ay + sy


out = []
out.append('<mxfile host="app.diagrams.net" type="device">')
out.append('  <diagram name="CSMS ERD (Chen)" id="csms-chen">')
out.append('    <mxGraphModel dx="1400" dy="900" grid="0" gridSize="10" guides="1" tooltips="1" '
           'connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1750" '
           'pageHeight="1560" math="0" shadow="0">')
out.append('      <root>')
out.append('        <mxCell id="0" />')
out.append('        <mxCell id="1" parent="0" />')

# cạnh vẽ trước để nằm dưới hình khối
for i, (a, b, card, _, _) in enumerate(edges):
    x1, y1 = anchor(a, b)
    x2, y2 = anchor(b, a)
    out.append(
        f'        <mxCell id="e{i}" style="endArrow=none;html=1;strokeColor=#6E7B85;'
        f'strokeWidth=2;edgeStyle=none;rounded=0;" edge="1" parent="1">')
    out.append('          <mxGeometry relative="1" as="geometry">')
    out.append(f'            <mxPoint x="{x1:.0f}" y="{y1:.0f}" as="sourcePoint" />')
    out.append(f'            <mxPoint x="{x2:.0f}" y="{y2:.0f}" as="targetPoint" />')
    out.append('          </mxGeometry>')
    out.append('        </mxCell>')
    # nhãn cardinality: đặt lệch 26% về phía a
    lx = x1 + (x2 - x1) * 0.26
    ly = y1 + (y2 - y1) * 0.26
    out.append(
        f'        <mxCell id="e{i}l" value="{card}" style="text;html=1;align=center;'
        f'verticalAlign=middle;fontSize=13;fontColor=#37474F;labelBackgroundColor=#FFFFFF;" '
        f'vertex="1" parent="1">')
    out.append(f'          <mxGeometry x="{lx-24:.0f}" y="{ly-11:.0f}" width="48" height="22" as="geometry" />')
    out.append('        </mxCell>')

for eid, (label, cx, cy, grey) in entities.items():
    fill = "#90A4AE" if grey else "#2196F3"
    out.append(
        f'        <mxCell id="{eid}" value="{label}" style="rounded=0;whiteSpace=wrap;html=1;'
        f'fillColor={fill};strokeColor=none;fontColor=#FFFFFF;fontSize=15;fontStyle=1;" '
        f'vertex="1" parent="1">')
    out.append(f'          <mxGeometry x="{cx-EW//2}" y="{cy-EH//2}" width="{EW}" height="{EH}" as="geometry" />')
    out.append('        </mxCell>')

for rid, (label, cx, cy) in rels.items():
    out.append(
        f'        <mxCell id="{rid}" value="{label}" style="rhombus;whiteSpace=wrap;html=1;'
        f'fillColor=#FF6D33;strokeColor=none;fontColor=#FFFFFF;fontSize=13;fontStyle=1;" '
        f'vertex="1" parent="1">')
    out.append(f'          <mxGeometry x="{cx-RW//2}" y="{cy-RH//2}" width="{RW}" height="{RH}" as="geometry" />')
    out.append('        </mxCell>')

legend = ("Chen notation — rectangle = entity, diamond = relationship. "
          "Cardinality (max, min):  &quot;1, 1&quot; exactly one  ·  &quot;1, 0&quot; at most one (nullable FK)  ·  "
          "&quot;N, 0&quot; zero or more  ·  &quot;N, 1&quot; one or more.&#10;"
          "AuditLog is standalone — UserID is a snapshot with no FK constraint (CR-11).")
out.append(f'        <mxCell id="legend" value="{legend}" style="text;html=1;align=left;'
           f'verticalAlign=middle;fontSize=12;fontColor=#546E7A;strokeColor=#CFD8DC;'
           f'fillColor=#FAFAFA;" vertex="1" parent="1">')
out.append('          <mxGeometry x="390" y="1370" width="1110" height="60" as="geometry" />')
out.append('        </mxCell>')

out.append('      </root>')
out.append('    </mxGraphModel>')
out.append('  </diagram>')
out.append('</mxfile>')

path = r"d:/PRM/Project/Src/Cafe-Shop-Management-System/docs/csms-erd-chen.drawio"
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"OK: {len(entities)} entities, {len(rels)} relationships, {len(edges)} edges")
