#include <iostream> 
#include <fstream>//文件流操作
#include <string>//字符串操作，在stoi(）中将字符串转化为整型
#include <windows.h>//实现混合颜色（显示不同颜色），清屏操作
#include <conio.h>//利用getch获取密码而不显示在控制台上
#include <cstdlib> // 引入C标准库的头文件，包含了一些常用的函数和宏定义
#include <vector>  // 引入C++标准库中的vector容器类，用于存储和操作动态数组
using namespace std;
string BookString;//字符串型Book，用于获取文件内容（读取文件只能是string）
int index;//全局变量，传递函数返回值（trey和search）
bool access = 0;//布尔值access，用于检查用户是否登录，是否有权限执行借还书操作
string username, password;//定义字符串用户名(username)和密码(password)，全局变量
int limit[13];//定义整型数组，limit[0]用于记录个人已借图书数目（最多可借12本），后面的元素用于记录所借图书
/*结构体Book，定义并初始化了图书信息
【索书号（整型：number），书名（number），书籍位置（place），作者（editor），出版社（publisher），在馆状态（state）*/
struct Book {
	string name, state, place, editor, publisher;
	int number;
};
/*函数接收结构体Book，size在借书和还书函数中有赋值*/
void text(Book a[], int size) {
	for (int i = 0; i < size; i++)
		a[i].number = 1000 + i;
	ifstream file1("state.control");
	ifstream file2("name.control");
	ifstream file3("writer.control");
	ifstream file4("publisher.control");
	string line1, line2, line3, line4;
	int j = 0;
	while (getline(file1, line1) && getline(file2, line2) && getline(file3, line3) && getline(file4, line4)) {//同时读取四个文件的同一行内容
		a[j].place = line1;
		a[j].name = line2;
		a[j].editor = line3;
		a[j].publisher = line4;
		j++;
	}

	file1.close();
	file2.close();
	file3.close();
	file4.close();
	ifstream fin("book.control");
	getline(fin, BookString);//getline(fin,a),a只能为字符串变量
	int len = BookString.length();//计算BookString的长度
	for (int con = 0; con < size; con++) {
		if (len > con) {
			a[con].state = BookString[con] == '0' ? "在馆" : "借出";//在book.control中，0表示在馆，1表示借出
		} else {
			a[con].state = "在馆";
		}
	}
	fin.close(); // 关闭文件
}
//搜索核心，对于普通用户，仅提供书名搜索（Type=0)；对于管理员，则可以使用索书号搜索(Type=1)
int trey(string SearchString, Book a[], int size, int Type) {
	if (Type == 0) {
		for (int k = 0; k < size; k++) {
			if (SearchString == a[k].name) {
				return k;
			}
		}
		return -1;
	} else if (Type == 1) {
		int SearchInt = stoi(SearchString);
		for (int k = 0; k < size; k++) {
			if (SearchInt == a[k].number) {
				return k;
			}
		}
		return -1;
	}
}

void check() {//检查必需文件是否齐全的函数
	bool yes = 0;
	ifstream fin1("book.control");//尝试打开文件
	HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);	// 获取标准输出句柄，用于设置控制台文本属性
	SetConsoleTextAttribute(hConsole, FOREGROUND_GREEN | FOREGROUND_RED);// 设置控制台文本属性为绿色和红色，通过位或运算符组合两种颜色
	if (!fin1.is_open()) {//如果找不到文件
		yes = 1;
		cout << "警告：找不到book.control，请联系你的管理员以解决问题" << endl;
	}
	fin1.close();
	ifstream fin2("user.control");
	if (!fin2.is_open()) {
		yes = 1;
		cout << "警告：找不到user.control，请联系你的管理员以解决问题" << endl;
	}
	fin2.close();
	ifstream fin3("pass.control");
	if (!fin3.is_open()) {
		yes = 1;
		cout << "警告：找不到pass.control，请联系你的管理员以解决问题" << endl;
	}
	fin3.close();
	ifstream fin4("name.control");
	if (!fin4.is_open()) {
		yes = 1;
		cout << "警告：找不到name.control，请联系你的管理员以解决问题" << endl;
	}
	fin4.close();
	ifstream fin5("name.control");
	if (!fin5.is_open()) {
		yes = 1;
		cout << "警告：找不到state.control，请联系你的管理员以解决问题" << endl;
	}
	fin5.close();
	ifstream fin6("writer.control");
	if (!fin6.is_open()) {
		yes = 1;
		cout << "警告：找不到writer.control，请联系你的管理员以解决问题" << endl;
	}
	fin6.close();
	ifstream fin7("publisher.control");
	if (!fin7.is_open()) {
		yes = 1;
		cout << "警告：找不到publisher.control，请联系你的管理员以解决问题" << endl;
	}
	fin7.close();
	ifstream fin8("limit.control");
	if (!fin8.is_open()) {
		yes = 1;
		cout << "警告：找不到limit.control，请联系你的管理员以解决问题" << endl;
	}
	fin7.close();
	SetConsoleTextAttribute(hConsole, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);//重置文本颜色为白色
	if (yes == 1) {//判断是否文件齐全，全在执行后续程序，否则退出
		getchar();//起到暂停程序效果
		exit(0);//退出
	}
}
//搜索函数，要调用trey(Type=0),通过返回值判断
void search() {
	Book a[1000];
	text(a, 1000);
	cout << "请输入书籍名：";
	string search;
	cin >> search;
	index = trey(search, a, 1000, 0);
	if (index != -1) {
		cout << "索书号：" << a[index].number << endl << "书籍位置：" << a[index].place << endl << "书籍名：" <<
		     a[index].name << endl << "作者：" << a[index].editor << endl << "出版社：" << a[index].publisher << endl <<
		     "状态：" << a[index].state << endl;
	} else {
		cout << "未找到此书" << endl;
		cout << "请重新输入操作：" << endl;
	}
}
//单独的管理员操作，目前不支持修改账户和密码
void administrator() {
	ifstream file("user.control");
	string line;
	int lineNumber1 = 0;
	bool found = false;
	string choice2, choice, control;
	string newuser, surepassword, newpassword;
	system("cls");//清屏操作
	cout << "欢迎来到管理员界面！账户操作请输入0，书籍操作请输入1，退出请输入2" << endl;
	do {
		cout << "请输入操作：";
		cin >> control;
		if (control == "0") {
			cout << "欢迎进入账户操作！查看所有用户账号密码请输入0，添加账户请输入1，退出请输入2"
			     << endl;
			do {
				cout << "请输入操作：";
				cin >> choice;
				if (choice == "1") {
					ifstream file("user.control");
					while (true) {
						cout << "请输入你需要创立的账号：";
						cin >> newuser;
						if (newuser == "0") {
							cout << "账号不符合要求，请重新输入！" << endl;
							continue;
						}
						bool found = false; // 重置found为false
						string line;
						// 重新定位到文件的开头，以便重新读取内容
						file.clear();
						file.seekg(0, ios::beg);

						while (getline(file, line)) {
							if (line == newuser) {
								found = true;
								cout << "用户名已存在！" << endl;
								break;
							}
						}
						if (found) {
							continue; // 如果找到用户名，提示用户并继续循环
						}

						// 如果用户名不存在，则添加新用户名到文件
						ofstream outfile("user.control", ios_base::app);
						outfile << endl << newuser;
						outfile.close();
						while (true) {
							char newpassword[20];
							char surepassword[20];
							int i = 0;
							char ch;
							cout << "请输入密码: ";
							while ((ch = _getch()) != '\r') { // 循环读取输入直到回车键,_getch()是迎合Visual Stdio的写法，在其他IDE中应使用getch()，为接收字符而不显示在控制台上
								if (ch == '\b') { // 如果是退格键
									if (i > 0) { // 如果密码长度不为0
										cout << "\b \b"; // 删除一个星号
										i--; // 减少密码长度
									}
								}
								else {
									newpassword[i++] = ch; // 存储输入的字符
									cout << '*'; // 显示星号
								}
								if (i >= sizeof(newpassword) - 1) break; // 如果达到密码数组大小限制则退出循环
							}
							newpassword[i] = '\0'; 
							cout <<endl<< "请再次输入密码：";
							i = 0; // 重置索引为0，这很重要
							while ((ch = _getch()) != '\r') { 
								if (ch == '\b') { 
									if (i > 0) { 
										cout << "\b \b";
										i--; 
									}
								}
								else {
									surepassword[i++] = ch; 
									cout << '*'; 
								}
								if (i >= sizeof(surepassword) - 1) break; 
							}
							surepassword[i] = '\0'; 
							if (strcmp(newpassword, surepassword) != 0) {//strcmp，比较两个字符串
								cout << endl << "两次输入的密码不一致，请重新输入！" << endl;
							}
							else {
								ofstream outfile1("pass.control", ios_base::app);
								outfile1 << endl << newpassword;
								outfile1.close();
								cout << endl<<"注册成功！" << endl;
								break; // 成功注册后退出密码循环
							}
						}
						break; // 成功注册后退出账号创建循环
					}
					file.close(); // 确保在循环结束后关闭文件
				} else if (choice == "0") {
					ifstream file1("user.control");
					ifstream file2("pass.control");
					string line1, line2;
					while (getline(file1, line1) && getline(file2, line2)) {
						HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
						SetConsoleTextAttribute(hConsole, FOREGROUND_BLUE);
						cout << "------------------------------------------------" << endl;
						SetConsoleTextAttribute(hConsole, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
						cout << "账号：" << line1 << endl << "密码：" << line2 << endl;
					}
					HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
					SetConsoleTextAttribute(hConsole, FOREGROUND_BLUE);
					cout << "------------------------------------------------" << endl;
					SetConsoleTextAttribute(hConsole, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
					file1.close();
					file2.close();
				}
			} while (choice != "2");
		} else if (control == "1") {
			cout << "欢迎进入书籍操作！搜索书籍请输入0，添加书籍请输入1，退出请输入2" << endl;
			do {
				string Type;
				cout << "请输入操作：";
				cin >> choice2;
				if (choice2 == "0") {
					cout << "请输入搜索类型（目前仅支持搜索名字和索书号）：";
					cin >> Type;
					if (Type == "名字")
						search();
					else if (Type == "索书号") {
						Book a[1000];
						text(a, 1000);
						cout << "请输入索书号：";
						string search;
						cin >> search;
						index = trey(search, a, 1000, 1);
						if (index != -1) {
							cout << "索书号：" << a[index].number << endl << "书籍位置：" << a[index].place << endl << "书籍名：" <<
							     a[index].name << endl << "作者：" << a[index].editor << endl << "出版社：" << a[index].publisher << endl <<
							     "状态：" << a[index].state << endl;
						} else {
							cout << "未找到此书" << endl;
							cout << "请重新输入操作：" << endl;
						}
					}
				} else if (choice2 == "1") {
					string name, publisher, place, editor, sure;
						cout << "输入图书名（不加书名号）：";
						cin >> name;
						cout << "输入作者名：";
						getline(cin, editor);//读取一行字符串，在MSVC中原gets被弃用
						cout << "输入所在位置：";						
					cin >> place;
					cout << "输入出版社：";
					cin >> publisher;
					cout << "是否添加(Y/N):";
					cin >> sure;
					if (sure == "Y") {
						ofstream outfile("name.control", ios_base::app);
						outfile <<name<<endl;
						outfile.close();
						ofstream outfile1("writer.control", ios_base::app);
						outfile1 << editor<<endl;
						outfile1.close();
						ofstream outfile2("state.control", ios_base::app);
						outfile2 <<  place<<endl;
						ofstream outfile3("publisher.control", ios_base::app);
						outfile3 << publisher<<endl;
						outfile3.close();
						cout << "录入书籍信息成功！" << endl;
					}
				}
			} while (choice2 != "2");
		}
	} while (control != "2");
	access = 0;
	system("cls");
	cout << "操作代码（1：登录；2：借书；3：还书；4：查找书籍；5：关于；6：退出）：" <<
	     endl;
}
/*用户登录系统，"0"为退出字*/
void user() {
	cout << "欢迎来到用户界面，请登录【退出账号输入0，注册请联系管理员】" << endl;
	int lineNumber1 = 0;  
	int lineNumber2 = 0;  // 定义行号变量lineNumber1，lineNumber2，用于控制读行
char ch; // 定义字符变量ch
if (access == 0) { // 如果access等于0，即用户未登录
	cout << "用户名："; 
	cin >> username; 
	if (username == "0") { // 如果用户名为"0"
	} else { // 如果用户名不为"0"
		char password[20]; 
		int i = 0; 
		char ch; 
		cout << "请输入密码： "; 
		while ((ch = _getch()) != '\r') { 
			if (ch == '\b') { 
				if (i > 0) { 
					cout << "\b \b"; 
					i--; 
				}
			}
			else { 
				password[i++] = ch; 
				cout << '*'; 
			}
			if (i >= sizeof(password) - 1) break; // 如果密码数组已满，跳出循环
		}
		password[i] = '\0';
		bool found = false; // 定义布尔变量found并初始化为false，用于判断是否在文件中找到内容
		ifstream file("user.control"); 
		string line;
		while (getline(file, line)) { // 逐行读取用户文件
			lineNumber1++; // 行号加1，读取下一行
			if (line == username) { 
				found = true; 
				break; // 跳出循环
			}
		}
		file.close(); 
		if (found) { // 如果找到了用户名
			bool found2 = false; // 定义布尔变量found2并初始化为false
			ifstream file2("pass.control"); // 打开密码文件
			string line2; 
			while (getline(file2, line2)) { 
				lineNumber2++; 
				if (lineNumber2 == lineNumber1 && line2 == password) { // 如果行号相等且读取的行与输入的密码相同
					found2 = true; 
					break; 
				}
			}
			file2.close(); // 关闭密码文件
			if (found2) { // 如果找到了密码
				cout << endl<<"登陆成功！欢迎您：" << username << "！" << endl; 
				if (username == "Administrator") { // 如果用户名为"Administrator"
					access = 1;
					administrator(); // 调用administrator函数，打开管理员专属页面
				} else { // 如果用户名不为"Administrator"
					ofstream fout("connect.temp"); //建立临时文件，写入username，便于后面的函数调用
					fout << username; 
					fout.close(); 
					access = 1;
				}
			} else { // 如果未找到密码
				cout << "密码输入错误 " << endl; 
				user(); // 调用user函数，重新登陆
			}
		} else { // 如果未找到用户名
			cout << endl<<"账号输入错误！ " << endl; 
			user();
		}
	}
} else { // 如果access不等于0，即用户已登录
	cout << "请先退出登录再继续……"; // 输出提示信息
	user(); // 调用user函数
}
}


//创建和录入用户个人借书信息
void use() {
	ifstream fout("limit.temp");
	fout >> username;
	fout.close();
	string fileName = "user/" + username + ".control";//打开当前目录的user文件夹，用于创建个人用户借阅信息文件
	ifstream inFile(fileName);//在指定的目录创建文件
	string temp;
	int size = 0;
	while (getline(inFile, temp)) {
		limit[size++] = stoi(temp);//将字符串it强制转换为整型，录入到limit
	}
	inFile.close();
}

//借书系统
void borrowBooks() {
	ifstream fin("connect.temp");
	string username;
	if (fin >> username) {
		fin.close();
		string fileName = "user/" + username + ".control";
		Book a[1000];//调用结构体数组
		text(a, 1000);//传输size值（1000）
		if (limit[0] <= 12) {//如果未达到结束上限（12本）
			if (access == 1) {//如果已登录
				cout << "请输入索书号：";
				int search;
				cin >> search;
				if (search >= 1000 && search < 2000) {
					search -=999 ;
					if (a[search].state == "在馆") {
						a[search].state = "借出";
						cout << "借出成功！" << endl;
						ofstream fout(fileName); 
						limit[0]++;//更新个人借书信息
						bool find = false;
						for (int k = 0; k < 13; k++) {
							if (limit[k] == NULL) {
								limit[k] = search;
								find = true;
								break; // 找到空位后退出循环
							}
						}
						if (find) {
							for (int k = 0; k < 13; k++) {
								fout << limit[k] << endl;
							}
						}
						fout.close(); // 在循环外部关闭文件流

						ofstream fout2("book.control");
						for (int i = 0; i < 1000; i++) {
							fout2 << (a[i].state == "在馆" ? '0' : '1');
						}
						fout2.close();
					}
					else {
						cout << "该书已被借阅！" << endl;
					}
				}
				else {
					cout << "无效的索书号，请重新输入！" << endl;
				}
			}
			else {
				cout << "请先登录……" << endl;
				user();
			}
		}
		else {
			cout << "已达到借书上限！" << endl;
		}
	}
	else {
		cout << "无法读取用户名！" << endl;
	}
}

//还书系统，和借书系统大同小异
void returnBooks() {
	ifstream fout("connect.temp");
	fout >> username;
	fout.close();
	if (access == 1) {
		Book a[1000];
		text(a, 1000);
		use();
		string fileName = "user/" + username + ".control";
		if (access == 1) {
			cout << "请输入索书号：";
			int search;
			cin >> search;
			if (search >= 1000 && search < 2000) {
				search -= 999;
				if (a[search].state == "借出") {
					a[search].state = "在馆";
					cout << "归还成功！" << endl;
					ofstream fout(fileName);
					limit[0]--;
					bool find = 0;
					for (int k = 0; k < 13; k++) {
						if (limit[k] == search)
						{
							limit[k] = NULL;
							find =true;
						}
						else
						{
							cout << "找不到书籍！" << endl;
						}
					}
					if (find)
					{
						for (int k = 0; k < 13; k++) 
						fout << limit[k] << endl;
					}
					fout.close();
					ofstream fout2("book.control");
					for (int i = 0; i < 1000; i++) {
						fout2 << (a[i].state == "在馆" ? '0' : '1');
					}
					fout2.close();
				} else {
					cout << "该书未被借阅！" << endl;
				}
			} else {
				cout << "无效的索书号，请重新输入！" << endl;
			}
		}
	} else {
		cout << "请先登录……" << endl;
		user();
	}
}

//关于页面
void about() {
	HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
	SetConsoleTextAttribute(hConsole, FOREGROUND_GREEN);
	cout << "                                  关                               于" << endl;
	SetConsoleTextAttribute(hConsole, FOREGROUND_RED);
	cout << "                   警告：请勿随意更改或删除control文件的内容，这可能导致程序出现错误！"
	     << endl;
	SetConsoleTextAttribute(hConsole, FOREGROUND_BLUE);
	cout << endl << "                                 图书管理系统";
	SetConsoleTextAttribute(hConsole, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
	cout << "  版本号：Vision1.0（正式版）" << endl;
	cout << "作者：BuBaiMengJ4&xiaoyu1145" << endl << "平台：Windows" << endl << "开源代码：在GitHub或Gitee上获取" <<
	     endl;
	cout << "------------------------------------------------------------------------------------------------------" <<
	     endl;
	cout << "程序介绍：\n" << "·一个简单的图书管理程序（CMD界面），可实现如下功能" << endl <<
	     "① 借书和还书操作\n② 普通账户登录\n③ 管理员账户的管理操作\n④ 通过图书名来检索图书"
	     << endl;
	cout << "------------------------------------------------------------------------------------------------------" <<
	     endl;
	cout << "更新内容：" << endl << "原始版本，可以实现简单的图书操作功能。" << endl;
	cout << "------------------------------------------------------------------------------------------------------" <<
	     endl;
	cout << "操作代码（0：获取帮助，1：发送反馈，2：退出）" << endl;
	string choice;
	do {
		cout << "请输入操作：";
		cin >> choice;
		if (choice == "0") {
			system("Help.html");//打开本地帮助文档
		} else if (choice == "1") {
			cout << "欢迎您给我们发送反馈，我们将会认真阅读您的反馈！" << endl;
			string url ="https://forms.office.com/Pages/ResponsePage.aspx?id=DQSIkWdsW0yxEjajBLZtrQAAAAAAAAAAAAN__jFEEqlUMVhLU0RFSE0yOUxLUlRMSDAzUDRQQUJTMS4u";
			string command = "start " + url;
			system(command.c_str());//打开浏览器，访问url定义的网页
		} else if (choice == "2")
			break;
		else
			cout << "无效的操作，请重新输入！" << endl;
	} while (true);
}

typedef void (*FuncPtr)();


int main() {
	check();
	cout << "操作代码（1：登录；2：借书；3：还书；4：查找书籍；5：关于；6：退出）：" <<endl;
	string choice;//字符串防止输入非整型的字符
	FuncPtr funcArray[] = { user, borrowBooks, returnBooks, search, about };//指针调用函数
	do {
		cout << "请输入操作：";
		cin >> choice;
		if (choice == "1" || choice == "2" || choice == "3" || choice == "4" || choice == "5") {
			int choiceInt = stoi(choice);//强制转换类型
			funcArray[choiceInt - 1]();//数组开头为0
		} else if (choice == "6") {
			const char *filename = "connect.temp";//删除temp文件
			cout << "感谢使用本程序，再见！" << endl;
			break;
		} else {
			cout << "无效的操作，请重新输入！" << endl;
			cout << "请重新输入操作：" << endl;
		}
	} while (true);
	return 0;
}