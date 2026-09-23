# Từng tầng

Mọi tầng dưới đây là folder con của **folder source mang tên target** (`MyApp/`,
sau init-base là `<Module>/`); test nằm ở `MyAppTests/`. Path trong file này tính
từ folder source.

Không có SPM package: tất cả là folder trong một app target. Nghĩa là **compiler
không chặn** một vi phạm phân tầng — file cùng module thấy nhau không cần
`import`. `tools/check-arch.sh` là thứ thay thế, và nó suy luật từ chính source:
đọc tên type khai báo dưới `Data/` rồi tìm chúng ở nơi không được biết.

`DesignSystem/Modifiers/` giữ modifier dùng chung (`onFirstAppear`,
`alert(_:onDismiss:)`, `cardStyle`, `dismissKeyboardOnTap`);
`DesignSystem/Components/` giữ view chung (`LoadableContent`, `LoadingView`,
`EmptyStateView`, `ErrorStateView`, `PrimaryButtonStyle`). Trước khi viết một
view hay modifier mới, soi hai folder này — `LoadableContent` ra đời vì cùng một
`switch` trên `Loadable` đã bị chép hai lần.

## Core/ — Foundation, không gì khác

`Loadable` · `AlertState` · `AppError` · `AppEnvironment`

`AppError` ở đây chứ không ở `Domain` vì mọi tầng đều nói nó (`Data` sinh ra,
`Domain` truyền đi, feature render) và `Loadable` cần nó. Đặt ở `Domain` thì
`Core` phải depend `Domain` — đảo graph vì một enum.

## Domain/ — thuần Swift

`Entities/` · `Repositories/` (protocol) · `UseCases/` · `Services/` (port) ·
`Errors/`

Port là những thứ như `ToastService`, `TokenStoring`: nói *cái gì cần làm được*
mà không nói *bằng gì*. Nhờ vậy `Domain` không import KVToastKit hay Security.

**Use case chỉ viết khi có logic thật** — validate, orchestrate nhiều repository,
một quy tắc nghiệp vụ. Forward một dòng sang repository không phải use case, đó
là nghi lễ; để ViewModel gọi repository trực tiếp.

`Entities/Fixtures.swift` ở đây vì fixture của một entity là phần vocabulary của
entity đó, và feature (vốn bị cấm import `Data`) cần nó cho preview và test.

## Data/ — biên giới của KVNetworkit

`DTO/` · `Network/Endpoints/` · `Network/Interceptors/` · `Mapping/` · `Local/` ·
`Repositories/` · `Testing/`

DTO là wire shape (field optional, tên theo backend); entity là cái app suy luận.
`toDomain()` là chỗ một cái thành cái kia, và là chỗ một optional thiếu thành
default thay vì để `nil` lọt lên trên.

`cachePolicy` khai theo từng endpoint có ý thức: list mà user pull-to-refresh có
thể serve bản ấm một phút, nhưng kết quả huỷ đơn thì không bao giờ được từ cache.

Stub ở `Testing/` chứ không ở test target, vì `KVDependencyKey.testValue` phải
gọi tên được chúng và khai báo đó nằm ở `DI` — cái sẽ ship.

## DI/ — nơi duy nhất khai key

Xem `references/di.md`.

## DesignSystem/

`Foundation/` (AppColor, AppFont, Spacing, Radius) · `Components/` · `Toast/`

Màu ship dưới dạng asset catalog (`App/Resources/Assets.xcassets/Colors/`) chứ không phải
Swift literal, để có biến dark và để người phụ trách design sửa được —
`figma-intake` sinh lại catalog, không sinh lại file Swift.

Tên theo **nghĩa**, không theo **giá trị**: `Semantic.error` sống sót khi designer
đổi đỏ sang cam; `red500` thành lời nói dối ngay lúc đó.

## Feature\* — một module là một luồng

`<Feature>Route.swift` · `<Screen>/{View,ViewModel}.swift` · component riêng của
màn.

Một module = một luồng (list + detail + sheet), không phải một màn. Trong luồng
dùng `pushView`; xuyên luồng dùng route. Xem `references/navigation.md`.

File ViewModel chỉ `import KVRouterCore`; file View mới được `import KVRouterKit`.

## App/ — chỉ đi dây

`MyApp.swift` (composition root) · `Navigation/AppRoutes.swift` ·
`Navigation/Middlewares/` · `Bootstrap/` · `Session/`

Đây là tầng duy nhất được biết tất cả. Nếu logic nghiệp vụ xuất hiện ở đây, nó
đặt sai chỗ.
