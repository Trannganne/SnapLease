HUONG DAN KHOI PHUC KET NOI SNAPLEASE MVC

1. Giai nen vao thu muc SnapLease_MVC.
2. Mo SnapLease_MVC/appsettings.json va thay DIEN_MAT_KHAU_SQL bang mat khau tai khoan sa SQL Server cua ban.
3. Dam bao Docker SQL Server dang chay va port 14330 duoc mo: docker compose ps
4. Chay: dotnet run -p:UseAppHost=false --urls http://localhost:5001
5. Truy cap http://localhost:5001/Home/Index

Luu y: HTTP 500 co the do truy van EF Core, database schema, SQL Server khong san sang, khong chi do thieu appsettings. Neu van loi, copy exception trong terminal de chan doan.
File appsettings.json trong ZIP la mau, khong chua mat khau that. Khong commit mat khau vao Git.
