# EP.3 / 5 — `page.spec.tsx` หน้าจอหลัก

> เอกสารชุด **Vitest Learning EP.3** — 1 ไฟล์เทส = 1 เอกสาร
> ไฟล์ที่อธิบายในเล่มนี้: `frontend/test/app/master/WPEF1121CostCenterMaster/page.spec.tsx`
> จำนวน test case: **7** · ระดับความยาก: **★★**
>
> ดูภาพรวมทั้งโฟลเดอร์และลำดับการอ่านได้ที่ [00-overview](vitest-lerning-ep3-00-overview.md)

---

# ส่วนที่ 5: `page.spec.tsx` — ทดสอบหน้าจอหลัก

## 5.1 แนวคิด: ทดสอบ "ตัวประกอบ" ไม่ใช่ "ตัวเนื้อหา"

`page.tsx` คือ component ที่เอา 2 ส่วนมาต่อกัน:
```
┌─────────────────────────┐
│  Search Criteria        │  ← search.criteria.tsx (มีเทสของตัวเองใน EP.2)
├─────────────────────────┤
│  DataGrid               │  ← datagrid.cost-center-master.tsx ([06-datagrid](vitest-lerning-ep3-06-datagrid.md))
└─────────────────────────┘
```

หน้าที่ของมันมีแค่ 2 อย่าง: **"แสดง section ไหนบ้าง"** และ **"ตั้งค่าเริ่มต้นอะไรตอน mount"**

เทสไฟล์นี้จึง **mock ลูกทั้งหมดทิ้ง**:

```ts
vi.mock('@/features/master/cost-center-master/search.criteria', () => ({
    __esModule: true,
    default: () => React.createElement('div', { 'data-testid': 'mock-search-criteria' }),
}));

vi.mock('@/features/master/cost-center-master/datagrid.cost-center-master', () => ({
    __esModule: true,
    default: () => React.createElement('div', { 'data-testid': 'mock-cost-center-datagrid' }),
}));
```

component ลูกถูกแทนด้วย `<div>` เปล่าที่มี `data-testid` — เทสแค่ถามว่า
**"div นั้นโผล่มาหรือไม่"** ก็พอ

> **ทำไมไม่ render ของจริง**: ถ้า render ลูกจริง เทส page จะพังทุกครั้งที่ลูกเปลี่ยน
> ทั้งที่ page เองไม่ได้ผิดอะไร — mock ทำให้เทส**แยกความรับผิดชอบ**ได้ชัด
>
> `__esModule: true` บอกระบบ module ว่า "นี่คือ ES module นะ" เพื่อให้ `default` export ทำงานถูก

### mock อื่นๆ

```ts
let mockLocale = 'en';
vi.mock('@/components/AppI18nProvider', () => ({ useLocale: () => ({ locale: mockLocale }) }));

beforeEach(() => { mockLocale = 'en'; });
```

**เทคนิคน่าสนใจ**: ใช้ตัวแปรข้างนอก `mockLocale` ทำให้แต่ละเทส**เปลี่ยนภาษาได้**
โดยไม่ต้อง mock ใหม่ และ `beforeEach` รีเซ็ตกลับเป็น `'en'` กันค้างข้ามเทส

---

## 5.2 Test Case ทีละตัว

### TC-PAGE-001 — Search Criteria ต้องแสดงเสมอ

```ts
it('TC-PAGE-001: always renders the Search Criteria section', () => {
    renderPage(buildStore(AppConstants.SCREEN_MODE.INIT));
    expect(screen.getByTestId('mock-search-criteria')).toBeInTheDocument();
});
```

**เช็คอะไร**: ฟอร์มค้นหาต้องอยู่ตลอด ไม่ว่า screenMode จะเป็นอะไร

---

### TC-PAGE-002 / 003 / 004 — ตารางแสดงเฉพาะบาง mode ⭐

```ts
it('TC-PAGE-002: renders the datagrid section in INIT mode', () => {
    renderPage(buildStore(AppConstants.SCREEN_MODE.INIT));
    expect(screen.getByTestId('mock-cost-center-datagrid')).toBeInTheDocument();
});

it('TC-PAGE-003: renders the datagrid section in SEARCH mode', () => {
    renderPage(buildStore(AppConstants.SCREEN_MODE.SEARCH));
    expect(screen.getByTestId('mock-cost-center-datagrid')).toBeInTheDocument();
});

it('TC-PAGE-004: does not render the datagrid section for a screenMode outside INIT/SEARCH', () => {
    renderPage(buildStore(AppConstants.SCREEN_MODE.ADD));
    expect(screen.queryByTestId('mock-cost-center-datagrid')).not.toBeInTheDocument();
});
```

**เช็คอะไร**: ตารางแสดงเฉพาะ `INIT` และ `SEARCH` เท่านั้น

| screenMode | ตาราง | TC |
|---|---|---|
| INIT | ✅ แสดง | TC-PAGE-002 |
| SEARCH | ✅ แสดง | TC-PAGE-003 |
| อื่นๆ (ADD) | ❌ ไม่แสดง | TC-PAGE-004 |

> ⚠️ **จุดที่ต้องจำ**: `getByTestId` vs `queryByTestId`
>
> | ฟังก์ชัน | หาไม่เจอแล้วเป็นยังไง | ใช้ตอนไหน |
> |---|---|---|
> | `getByTestId` | **throw error ทันที** | ตอนคาดหวังว่า**ต้องมี** |
> | `queryByTestId` | คืน `null` เงียบๆ | ตอนคาดหวังว่า**ต้องไม่มี** |
>
> ถ้า TC-PAGE-004 เขียนด้วย `getByTestId` จะ error ก่อนถึงบรรทัด `expect` เสมอ
> — ต้องใช้ `queryByTestId` คู่กับ `not.toBeInTheDocument()` เท่านั้น

---

### TC-LOCALE-001 — เปลี่ยนภาษาแล้วต้องไม่พัง

```ts
it('TC-LOCALE-001: renders with the Thai date-fns adapter locale when the app locale is "th"', () => {
    mockLocale = 'th';
    renderPage(buildStore(AppConstants.SCREEN_MODE.INIT));
    expect(screen.getByTestId('mock-search-criteria')).toBeInTheDocument();
});
```

**เช็คอะไร**: `page.tsx` เลือก locale ของ date adapter ตามภาษาแอป
(`en` → locale อังกฤษ, `th` → locale ไทย)

เทสนี้เป็น **smoke test** — ไม่ได้เช็คว่า locale ไทยถูกใช้จริงไหม (ยากเกินระดับ unit test)
แต่เช็คว่า **path โค้ดเส้นนี้รันแล้วไม่ crash**

**ทำไมยังมีค่า**: ถ้า import locale ไทยผิดชื่อ หรือไฟล์ locale หาย
→ จะพังเป็น error ตอน render ทันที เทสนี้จับได้

> นี่คือตัวอย่าง test ที่ "อ่อน" (assert ไม่ลึก) แต่ยังคุ้มค่าที่จะมี
> เพราะต้นทุนต่ำและครอบคลุม branch ที่ไม่มีใครทดสอบ

---

## 5.3 TC-PAGE-005 / TC-PAGE-006 — sync page size ตอน mount ⭐

```ts
it('TC-PAGE-005: syncs the live app-config default page size into the feature slice on mount', () => {
    const store = buildStore(AppConstants.SCREEN_MODE.INIT, 25);
    renderPage(store);
    expect(store.getState().wpef1121CostCenterMasterReducer.datagrid.paginationModel.pageSize).toBe(25);
});

it('TC-PAGE-006: does not override an already-changed page size (rxSyncDefaultPageSize only applies to the untouched default)', () => {
    const initialState = reducer(undefined, { type: '@@INIT' });
    const store = configureStore({
        // ...
        preloadedState: {
            wpef1121CostCenterMasterReducer: {
                ...initialState,
                datagrid: { ...initialState.datagrid, paginationModel: { page: 0, pageSize: 50 } },  // user เลือก 50 ไว้
            },
            appConfigReducer: { datagridPageSize: { default: 25, options: [...] }, status: 'idle' },
        },
    });
    renderPage(store);
    expect(store.getState().wpef1121CostCenterMasterReducer.datagrid.paginationModel.pageSize).toBe(50);   // ต้องไม่ถูกทับเป็น 25
});
```

**เช็คอะไร**: คู่นี้คือ **TC-PAG-003/004 ของ slice แต่มองจากชั้น component**

| ชั้น | TC | ทดสอบอะไร |
|---|---|---|
| slice ([04-rtk-slice](vitest-lerning-ep3-04-rtk-slice.md)) | TC-PAG-003/004 | **reducer** `rxSyncDefaultPageSize` ตัดสินใจถูกไหม |
| page (ส่วนนี้) | TC-PAGE-005/006 | **component** เรียก reducer นั้นตอน mount จริงไหม |

**ทำไมต้องเทสทั้ง 2 ชั้น**: reducer อาจถูกต้องเป๊ะ แต่ถ้า component ลืมเรียก (ลืมใส่ `useEffect`)
ก็ไม่มีประโยชน์ — TC-PAGE-005 คือตัวพิสูจน์ว่า "สายไฟต่อถึงกัน"

> สังเกตว่า TC-PAGE-006 ต้องเขียน `configureStore` เองแทนที่จะใช้ `buildStore`
> เพราะต้องตั้ง `pageSize: 50` ที่ลึกเข้าไปใน `datagrid.paginationModel`
> ซึ่ง `buildStore` ไม่ได้เปิดให้ตั้ง — เป็นเรื่องปกติที่บางเทสต้อง "สร้างเองพิเศษ"

---

## 5.4 สรุปส่วนที่ 5

| เทคนิค | ใช้ยังไง |
|---|---|
| mock component ลูกทั้งหมด | ทดสอบเฉพาะ "การประกอบร่าง" ไม่ปนกับเนื้อหาลูก |
| `getByTestId` vs `queryByTestId` | "ต้องมี" ใช้ get, "ต้องไม่มี" ใช้ query |
| ตัวแปรข้างนอก + `beforeEach` รีเซ็ต | ทำให้ mock เปลี่ยนค่าได้รายเทส |
| smoke test | assert เบาๆ แต่ครอบคลุม branch ที่หลุดง่าย |
| เทสซ้ำ 2 ชั้น | reducer ถูก + component เรียกจริง ต้องมีทั้งคู่ |

---

