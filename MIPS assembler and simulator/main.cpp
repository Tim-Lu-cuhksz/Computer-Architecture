#include <iostream>
#include <cmath>
#include <string>
#include <sstream>
#include <fstream>
#include <map>
#include <set>
#include <vector>

using namespace std;

const int LEN_op = 6;
const int LEN_rs = 5;
const int LEN_rt = 5;
const int LEN_rd = 5;
const int LEN_shamt = 5;
const int LEN_funct = 6;
const int LEN_imm = 16;
const int LEN_address = 26;
const string INIT_addr = "100000";

static string current_addr = INIT_addr;

const int SIZE = 6000000/4;
const int REG_SIZE = 32;
const string INIT_ADDR = "400000";

/*-----Memory & Register Simulation----*/
int *p_text = new int [SIZE];
int *p_stack = p_text + SIZE;
int *p_data = p_text + SIZE/6 * 5;
int *p_heap = p_text + SIZE/6 * 4;
int *p_heap_top = p_heap;
uintptr_t BASE_ADDR = (uintptr_t) p_text;

static const set<string> r_type = {"add", "addu", "and", "clo", "clz", "div", "divu", "mult", "mul",
                            "madd", "msub", "maddu", "msubu", "nor", "or", "sll", "sllv", "sra", "multu",
                            "srav", "srl", "srlv", "sub", "subu", "xor", "slt", "sltu", "jalr", "teq",
                            "tne", "tge", "tgeu", "tlt", "tltu", "mfhi","mflo", "mthi", "mtlo"};

static const set<string> i_type = {"addi", "addiu", "andi", "ori", "xori", "lui", "slti", "sltiu", "beq",
                            "bgez", "bgezal", "bgtz", "blez", "bltzal", "bltz", "bne", "teqi", "jr",
                            "tnei", "tgei", "tgeiu", "tlti", "tltiu", "lb", "lbu", "lh", "lhu",
                            "lw", "lwc1", "lwl", "lwr", "ll", "sb", "sh", "sw", "swl", "swr", "sc"};

static const set<string> j_type = {"j", "jal"};

static const map<string,int> reg = {
    {"zero",0}, {"at",1}, {"v0",2}, {"v1",3}, {"a0",4}, {"a1", 5},
    {"a2",6}, {"a3",7}, {"t0",8}, {"t1",9}, {"t2",10}, {"t3",11},
    {"t4",12}, {"t5",13}, {"t6",14}, {"t7",15}, {"s0",16}, {"s1",17},
    {"s2",18}, {"s3",19}, {"s4",20}, {"s5",21}, {"s6",22}, {"s7",23},
    {"t8",24}, {"t9",25}, {"k0",26}, {"k1",27}, {"gp",28}, {"sp",29},
    {"fp",30}, {"ra",31}
};

static const map<string,string> op_hex = {
    {"add","0"}, {"addu","0"}, {"addi","8"}, {"addiu","9"}, {"and","0"}, {"andi","c"}, {"clo","1c"},
    {"clz","1c"}, {"div","0"}, {"divu","0"}, {"mult","0"}, {"multu","0"}, {"mul","1c"}, {"madd","1c"},
    {"maddu","1c"}, {"msub","1c"}, {"msubu","1c"}, {"nor","0"}, {"or","0"}, {"ori","d"}, {"sll","0"},
    {"sllv","0"}, {"sra","0"}, {"srav","0"}, {"srl","0"}, {"srlv","0"}, {"sub","0"}, {"subu","0"},
    {"xor","0"}, {"xori","e"}, {"lui","f"}, {"slt","0"}, {"sltu","0"}, {"slti","a"}, {"sltiu","b"},
    {"beq","4"}, {"bgez","1"}, {"bgezal","1"}, {"bgtz","7"}, {"blez","6"}, {"bltzal","1"}, {"bltz","1"},
    {"bne","5"}, {"j","2"}, {"jal","3"}, {"jalr","0"}, {"jr","0"}, {"teq","0"}, {"teqi","1"},
    {"tne","0"}, {"tnei","1"}, {"tge","0"}, {"tgeu","0"}, {"tgei","1"}, {"tgeiu","1"}, {"tlt","0"},
    {"tltu","0"}, {"tlti","1"}, {"tltiu","1"},{"lb","20"}, {"lbu","24"}, {"lh","21"}, {"lhu","25"},
    {"lw","23"}, {"lwcl","31"}, {"lwl","22"}, {"lwr","26"}, {"ll","30"}, {"sb","28"}, {"sh","29"},
    {"sw","2b"},  {"swl","2a"}, {"swr","2e"}, {"sc","38"}, {"mfhi","0"}, {"mflo","0"}, {"mthi","0"},
    {"mtlo","0"},
};

static const map<string,string> funct_hex = {
    {"add","20"}, {"addu","21"}, {"and","24"}, {"clo","21"},  {"clz","20"},  {"div","1a"},
    {"divu","1b"}, {"mult","18"}, {"multu","19"}, {"mul","2"}, {"madd","0"}, {"maddu","1"},
    {"msub","4"}, {"msubu","5"}, {"nor","27"}, {"or","25"}, {"sll","0"}, {"sllv","4"}, {"sra","3"},
    {"srav","7"}, {"srl","2"}, {"srlv","6"}, {"sub","22"}, {"subu","23"}, {"xor","26"}, {"slt","2a"},
    {"sltu","2b"}, {"jalr","9"}, {"teq","34"}, {"tne","36"}, {"tge","30"}, {"tgeu","31"},
    {"tlt","32"}, {"tltu","33"}, {"mfhi","10"}, {"mflo","12"}, {"mthi","11"}, {"mtlo","13"},
};

static const map<string,string> i_rt = {
    {"bgez","1"}, {"bgezal","11"}, {"bgtz","0"}, {"blez","0"}, {"bltzal","10"}, {"bltz","0"},
    {"jr","0"}, {"teqi","c"}, {"tnei","e"}, {"tgei","8"}, {"tgeiu","9"}, {"tlti","a"}, {"tltiu","b"},
};

// In hexadicimal form
static map<string,string> label_addr = {  };

struct Instruction {
    char type;
    string op, rs, rt, rd,shamt, funct, imm, address;
};

struct Data {
    string type;
    int length;
    char *char_addr;
    int *int_addr;
};

int binaryToDecimal(string str) {
    int result = 0, j = 0;
    for (int i = str.length() - 1; i >= 0; i--) {
        if (str[i] == '1') {
            result += pow(2,j);
        }
        j++;
    }
    return result;
}

int hexToDecimal(string str) {
    int result = 0, j = 0;
    for (int i = str.length() - 1; i >= 0; i--) {
        switch (str[i]) {
        case '1': case '2': case '3': case '4': case '5':
        case '6': case '7': case '8': case '9': case '0':            result += int(str[i] - '0') * pow(16,j);
            break;
        case 'A': case 'a':
            result += 10 * pow(16,j);
            break;
        case 'B': case 'b':
            result += 11 * pow(16,j);
            break;
        case 'C': case 'c':
            result += 12 * pow(16,j);
            break;
        case 'D': case 'd':
            result += 13 * pow(16,j);
            break;
        case 'E': case 'e':
            result += 14 * pow(16,j);
            break;
        case 'F': case 'f':
            result += 15 * pow(16,j);
            break;
        }
        j++;
    }
    return result;
}

string decimalToBinary(int n) {
    string result = "";
    while (n != 0) {
        if (n % 2 == 1) {
            result = "1" + result;
        } else {
            result = "0" + result;
        }
        n /= 2;
    }
    return result;
}

string decimalToHex(int n) {
    stringstream ss;
    ss << std::hex << n;
    string res ( ss.str() );
    return res;
}

string hexAdd(string add1, string add2) {
    int a1 = hexToDecimal(add1);
    int a2 = hexToDecimal(add2);
    return decimalToHex(a1+a2);
}


string extendZero(string num, int len) {
    //int i = num.find("\0");
    //if (i != -1) num = num.substr(0,i);
    while (int(num.length()) != len) {
        num = '0' + num;
    }
    return num;
}

string extendOne(string num, int len) {
    //int i = num.find("\0");
    //if (i != -1) num = num.substr(0,i);
    while (int(num.length()) != len) {
        //cout << num.length() << endl;
        num = '1' + num;
    }
    return num;
}

// 2's complement after bit extension
string twoComplement(string num) {
    string result = "";

    bool find_one = false;
    for (int i = num.length()-1; i >= 0; i--) {
        if (!find_one) {
            result = num[i] + result;
            if (num[i] == '1') find_one = true;
        } else {
            if (num[i] == '0') result = '1' + result;
            else result = '0' + result;
        }
    }
    return result;
}

string cutSpace(string str) {
    // cut blank space
    string result = "";
    for (unsigned int i = 0; i < str.length(); i++) {
        if (str[i] != ' ') result += str[i];
    }
    // cut tab spaace
    int i = result.find("\t",0);
    if (i != -1) {
        result = result.substr(0,i) + result.substr(i+1,result.length()-i-1);
    }
    return result;
}

string cutComments(string str) {
    int i = str.find('#',0);
    return str.substr(0,i);
}

bool isRType(string str) { // cut string
    int i = str.find('$',0);
    string command = str.substr(0,i);
    return r_type.count(command) != 0;
}

bool isIType(string str) {
    int i = str.find('$',0);
    string command = str.substr(0,i);
    return i_type.count(command) != 0;
}

bool isJType(string str) {
    int i = str.find('$',0);
    string command = str.substr(0,i);
    return j_type.count(command) != 0;
}

Instruction* getMachineCode(string s) {
    Instruction* p = new Instruction;
    string str = cutComments( cutSpace(s) );
    if (str == "syscall") {
        // We treat syscall as J type for simplicity
        p->type = 'J';
        p->op = extendZero("0",LEN_op);
        p->address = extendZero("0",LEN_address);
        p->address[LEN_address-4] = '1';
        p->address[LEN_address-3] = '1';
        return p;
    }
    else if (isRType(str)) {
        int i = str.find('$',0);
        int j = str.find('$', i+1);
        int k = str.find('$', j+1);
        string command = str.substr(0,i);
        string shamt,rs,rt;
        /*
        cout << str << endl;
        cout << command << endl;
        cout << command.length() << endl;
        */
        /*----------Register Checking------------*/
        if (command == "mtlo" || command == "mthi" || command == "tltu" || command == "tlt" ||
                command == "tge" || command == "tgeu" || command == "teq" || command == "tne" ||
                command == "msub" || command == "msubu" || command == "madd" || command == "maddu" ||
                command == "multu" || command == "mult" || command == "divu" || command == "div") {
            p->rd = extendZero("0",LEN_rd);
            k = j;
            j = i;
        } else {
            p->rd = extendZero( decimalToBinary( reg.at(str.substr(i+1,2)) ),LEN_rd);
        }
        //cout << p->rd << endl;

        if (command == "mfhi" || command == "mflo") {
            p->rs = extendZero("0",LEN_rs);
        } else {
            int l = str.find(',',j+1);
            rs = str.substr(j+1,l-j-1);
            p->rs = extendZero( decimalToBinary( reg.at(rs) ),LEN_rs);
        }
        //cout << p->rs << endl;

        if (command == "clo" || command == "clz" || command == "jalr" || command == "mfhi" ||
                command == "mflo" || command == "mthi" || command == "mtlo") {
            p->rt = extendZero("0",LEN_rt);
        } else {
            if (command == "sll" || command == "sra" || command == "srl"){
                p->rt = p->rs;
            } else {
                rt = str.substr(k+1,str.length()-k-1);
                p->rt = extendZero( decimalToBinary( reg.at(rt) ),LEN_rt);
            }
        }
        // Special case checking
        if (command == "jalr") {
            string tmp = p->rd;
            p->rd = p->rs;
            p->rs = tmp;
        }
        if (command == "sllv" || command == "srav" || command == "srlv") {
            string tmp = p->rs;
            p->rs = p->rt;
            p->rt = tmp;
        }
        /*----------Register Checking------------*/
        if (command == "sll" || command == "sra" || command == "srl") {
            //p->rt = p->rs;
            p->rs = extendZero("0",LEN_rs);
            // Something strange might happen here
            int l = str.find(',',j);
            shamt = extendZero( decimalToBinary(stoi(str.substr(l+1,str.length()-l-1))),LEN_shamt );
        } else {
            shamt = extendZero("0",LEN_shamt);
        }

        p->type = 'R';
        p->op = extendZero( decimalToBinary( hexToDecimal( op_hex.at(command) ) ),LEN_op );

        p->shamt = shamt;
        p->funct = extendZero( decimalToBinary(hexToDecimal(funct_hex.at(command))),LEN_funct);
        //cout << p->funct << endl;

        return p;
    }
    else if (isIType(str)) {
        int i = str.find('$',0);
        int j = str.find('$', i+1);
        string command = str.substr(0,i);
        string rt,rs;

        //cout << str<< endl;
        //cout << command<<endl;

        if (command == "bgez" || command == "bgezal" || command == "bgtz" ||
                command == "bltzal" || command == "bltz" || command == "blez" ||
                command == "teqi" || command == "tnei" || command == "tgei" ||
                command == "tgeiu" || command == "tlti" || command == "tltiu"){
            rt = decimalToBinary(hexToDecimal(i_rt.at(command)));
            p->rt = extendZero(rt, LEN_rt);
            j = i;
        } else {
            if (command != "jr") {
                int k = str.find(',',i+1);
                rt = str.substr(i+1,k-i-1);
            } else {
                rt = str.substr(i+1,2);
            }

            p->rt = extendZero( decimalToBinary( reg.at(rt) ),LEN_rt);
        }
        //cout << "Register rt: " << p->rt << endl;

        if (command == "lui" || command == "jr") {
            p->rs = extendZero("0",LEN_rs);
            j = i;
        } else {

            int k = str.find(',',j+1);
            rs = (k!=-1)?str.substr(j+1,k-j-1):str.substr(j+1,2);
            p->rs = extendZero( decimalToBinary( reg.at(rs) ),LEN_rs);
        }
        //cout << "Register rs: " << p->rs << endl;
        string imm;
        if (command == "lb" || command == "lbu" || command == "lh" || command == "lhu" ||
                command == "lw" || command == "lwc1" || command == "lwl" ||command == "lwr" ||
                command == "ll" || command == "sb" || command == "sh" || command == "sw" ||
                command == "swl" || command == "swr" || command == "sc") {
            imm = str.substr(i+4,j-i-5);
        } else if (command != "jr") {
            /* May be troublesome*/
            int l = str.find(',',j);
            imm = str.substr(l+1,str.length()-l-1);
        } else {
            imm = extendZero( decimalToBinary( hexToDecimal("8") ), LEN_imm);
        }
        //cout << "imm: " <<imm << endl;
        if (command == "beq" || command == "bgez" || command == "bgezal" || command == "bgtz" ||
                command == "blez" || command == "bltzal" || command == "bltz" || command == "bne") {
            // PC relative address

            int target = hexToDecimal(label_addr.at(imm));
            int current = hexToDecimal(current_addr);
            int diff = (target - current - 4)/4;
            p->imm = (diff>0)?extendZero(decimalToBinary(diff),LEN_imm):
                              extendOne(twoComplement(decimalToBinary(-diff)),LEN_imm);
            //cout << "imm: " <<p->imm << endl;
        } else if (command != "jr") {
            if (imm[0] == '-') {
                //cout << decimalToBinary( stoi(imm.substr(1,imm.length()-1))) << endl;
                string result = twoComplement( decimalToBinary( stoi(imm.substr(1,imm.length()-1))));
                // Negative number
                //cout << result << endl;
                p->imm = extendOne(result,LEN_imm );
            } else p->imm = extendZero(decimalToBinary(stoi(imm)),LEN_imm);
        } else p->imm = imm;
        //cout <<p->imm.length()<<" | " <<p->imm << endl;
        if (command == "beq" || command == "bne" || command == "jr") {
            string tmp = p->rs;
            p->rs = p->rt;
            p->rt = tmp;
        }
        p->type = 'I';
        p->op = extendZero( decimalToBinary( hexToDecimal( op_hex.at(command) ) ),LEN_op );
        return p;
    } else {
        string label,command;
        int i = s.find('j',0);
        int j = s.find(' ',i);
        command = s.substr(i,j-i);
        //cout << command<<endl;
        if (command == "j") {
            label = str.substr(1,str.length()-1);
            int address = hexToDecimal( label_addr.at(label) )/4;
            //cout << decimalToBinary(address) << endl;
            p->address = extendZero(decimalToBinary(address),LEN_address);
            // Cannot figure out why???
            int m = p->address.find('1',0);
            if (m>5) {
                p->address[m] = '0';
                p->address[5] = '1';
            }

        } else {
            label = str.substr(3,str.length()-3);
            //cout << "label: " <<label_addr.at(label) << endl;
            int address = hexToDecimal( label_addr.at(label) )/4;
            p->address = extendZero(decimalToBinary(address),LEN_address);
            int m = p->address.find('1',0);
            if (m>5) {
                p->address[m] = '0';
                p->address[5] = '1';
            }
        }
        //cout << label << endl;

        p->type = 'J';
        p->op = extendZero( decimalToBinary( hexToDecimal( op_hex.at(command) ) ),LEN_op );
        return p;

    }
    return nullptr;
}

string getMachineCode(Instruction* ip) {
    if (ip->type == 'R') {
        string s = ip->op + ip->rs + ip->rt + ip->rd + ip->shamt + ip->funct;
        //cout << s << endl;
        return s;
     } else if (ip->type == 'I') {
        // Need more attention
        string s = ip->op + ip->rs + ip->rt + ip->imm;
        //cout << s << endl;
        return s;
    } else {
        string s = ip->op + ip->address;
        //cout << s << endl;
        return s;
    }
}

void in_out_file(char* in_name, vector<string> &v, ofstream & outfile) {
    ifstream infile1,infile2;
    //string name = "D:/CUHKsz/2021/spring/CSC3050/project/project1/assembler-sample/3.in";
    infile2.open(in_name);
    string line1,line2;
    bool flag = true;
    while (getline(infile2, line2)) {
        string mips = cutComments(cutSpace(line2));

        if (mips == ".data") {
            flag = false;
            //continue;
        }
        if (mips == ".text"){
            flag = true;
            continue;
        }
        if (flag) {
            if (mips == "") continue;
            int i = mips.find(':');
            //cout << mips << endl;
            bool indicator = false;

            if (i != -1) {
                string label = mips.substr(0,i);

                if (int(mips.length()) == i+1) {
                    // Something may go wrong
                    //string next_addr = hexAdd(current_addr,"4");
                    label_addr.insert({label,current_addr});
                    indicator = true;
                } else {
                    label_addr.insert({label,current_addr});
                }
            }
            if (indicator) {
                indicator = false;
            } else current_addr = hexAdd(current_addr,"4");
        }

    }
    infile2.close();

    current_addr = INIT_addr;

    //ofstream outfile;
    //string name_out = "D:/CUHKsz/2021/spring/CSC3050/project/project1/machineCode.txt";
    //outfile.open(out_name.c_str());

    infile1.open(in_name);
    flag = true;
    while (getline(infile1, line1)) {
        string mips = cutComments(cutSpace(line1));
        //cout << mips << endl;
        if (mips == ".data") {
            flag = false;
            //continue;
        }
        if (mips == ".text"){
            flag = true;
            continue;
        }
        if (flag) {
            if (mips == "") continue;
            int i = mips.find(':');
            bool indicator = false;
            if (i != -1) {
                //string label = mips.substr(0,i);
                if (int(mips.length()) != i+1) {
                    int j = line1.find(':');
                    //cout << line1.substr(j+1,line1.length()-j) << endl;
                    Instruction *ip = getMachineCode(line1.substr(j+1,line1.length()-j));
                    cout << getMachineCode(ip) << endl;
                    v.push_back(getMachineCode(ip));
                    outfile << getMachineCode(ip) << endl;
                } else indicator = true;
            } else {
                Instruction *ip = getMachineCode(line1);
                cout << getMachineCode(ip) << endl;
                v.push_back(getMachineCode(ip));
                outfile << getMachineCode(ip) << endl;
            }
            if (indicator) indicator = false;
            else current_addr = hexAdd(current_addr,"4");
        }

    }
    infile1.close();
    //outfile.close();
}


/* New methods */
string hexSub(string add1, string add2) {
    int a1 = hexToDecimal(add1);
    int a2 = hexToDecimal(add2);
    return decimalToHex(a1-a2);
}

string simToReal(int *p, string sim_addr) {
    stringstream ss;
    ss << p;
    string str = hexAdd(ss.str(),sim_addr);
    return hexSub(str,INIT_ADDR);
}


void add(int *rd,int *rs,int *rt) {
    *rd = *rs + *rt;
}

void addu(int *rd, int *rs, int *rt) {
    *rd = abs(*rs) + abs(*rt);
}

void addi(int *rt, int *rs, int imm) {
    *rt = *rs + imm;
}

void addiu(int *rt, int *rs, int imm) {
    *rt = abs(*rs) + imm;
}

void _and(int *rd, int *rs, int *rt) {
    *rd = *rs & *rt;
}

void _andi(int *rd, int *rs, int imm) {
    *rd = *rs & imm;
}

void clo(int *rd, int *rs) {
    int cnt = 0;
    string num;
    if (*rs >= 0) {
        num = extendZero( decimalToBinary(*rs), REG_SIZE);
    } else {
        num = twoComplement(extendZero(decimalToBinary(-(*rs)), REG_SIZE));
    }
    for (unsigned int i = 0; i < num.length(); i++) {
        if (num[i] == '0') break;
        cnt++;
    }
    *rd = cnt;
}

void clz(int *rd, int *rs) {
    int cnt = 0;
    string num;
    if (*rs >= 0) {
        num = extendZero( decimalToBinary(*rs), REG_SIZE);
    } else {
        num = twoComplement(extendZero(decimalToBinary(-(*rs)), REG_SIZE));
    }
    for (unsigned int i = 0; i < num.length(); i++) {
        if (num[i] == '1') break;
        cnt++;
    }
    *rd = cnt;
}

void _div(int *rs, int *rt, int *lo, int *hi) {
    *lo = (*rs)/(*rt);
    *hi = (*rs)%(*rt);
}

void divu(int *rs, int *rt, int *lo, int *hi) {
    *lo = abs((*rs)/(*rt));
    *hi = abs((*rs)%(*rt));
}

void mult(int *rs, int *rt, int *lo, int *hi) {
    int r = (*rs) * (*rt);
    string result;
    if (r >= 0) {
        result = extendZero( decimalToBinary(r),64);
    } else {
        result = extendOne( twoComplement( decimalToBinary(-r)),64);
    }
    *lo = binaryToDecimal( result.substr(0,31) );
    *hi = binaryToDecimal( result.substr(32) );

}

void mulu(int *rs, int *rt, int *lo, int *hi) {
    string result = extendZero( decimalToBinary( abs((*rs) *(*rt))), 64);
    *lo = binaryToDecimal( result.substr(0,31) );
    *hi = binaryToDecimal( result.substr(32) );
}

void mul(int *rd, int *rs, int *rt) {
    int r = (*rs) * (*rt);
    string result;
    if (r >= 0) {
        result = extendZero( decimalToBinary(r),64);
    } else {
        result = extendOne( twoComplement( decimalToBinary(-r)),64);
    }
    *rd = binaryToDecimal(result.substr(32));
}

void madd(int*rs, int*rt, int*lo, int*hi) {
    int result = (*rs) * (*rt);
    string s,h,l;
    if (result >= 0){
        s = extendZero( decimalToBinary(result),2*REG_SIZE );
    } else {
        s = twoComplement(extendZero(decimalToBinary(-(result)), 2*REG_SIZE));
    }
    h = s.substr(0,REG_SIZE);
    l = s.substr(REG_SIZE,REG_SIZE);
    *lo = binaryToDecimal(l)+ (*lo);
    *hi = binaryToDecimal(h)+ (*hi);
}

void maddu(int*rs, int*rt, int*lo, int*hi) {
    int result = abs((*rs) * (*rt));
    string s,h,l;
    s = extendZero( decimalToBinary(result),2*REG_SIZE );

    h = s.substr(0,REG_SIZE);
    l = s.substr(REG_SIZE,REG_SIZE);
    *lo = binaryToDecimal(l) + (*lo);
    *hi = binaryToDecimal(h) + (*hi);
}

void msub(int*rs, int*rt, int*lo, int*hi) {
    int result = abs((*rs) * (*rt));
    string s,h,l;
    s = extendZero( decimalToBinary(result),2*REG_SIZE );
    h = s.substr(0,REG_SIZE);
    l = s.substr(REG_SIZE,REG_SIZE);
    *lo = (*lo) - binaryToDecimal(l);
    *hi = (*hi) - binaryToDecimal(h);
}

void msubu(int*rs, int*rt, int*lo, int*hi) {
    int result = abs((*rs) * (*rt));
    string s,h,l;
    s = extendZero( decimalToBinary(result),2*REG_SIZE );
    h = s.substr(0,REG_SIZE);
    l = s.substr(REG_SIZE,REG_SIZE);
    *lo = (*lo) - binaryToDecimal(l);
    *hi = (*hi) - binaryToDecimal(h);
}


void execution(vector<string> & v, int* *p,
               ifstream & infile, ofstream& outfile) {
    /* syscall implementation */
    for (unsigned int num_line = 0; num_line < v.size(); num_line++) {
        string instruction = v[num_line];
        if (instruction == "00000000000000000000000000001100") {
            int v0 = *(p[2]);
            if (v0 == 1) {
                outfile << *(p[4]);
            } else if (v0 == 4) {
                char* read_addr = (char*)(*(p[4]) + BASE_ADDR);
                while ((*read_addr) != '\0') {
                    // May be troublesome
                    outfile << *read_addr++;
                }
            } else if (v0==5) {
                string in_str;
                getline(infile, in_str);
                *(p[2]) = stoi(in_str);
            } else if (v0==8){
                string in_str;
                getline(infile, in_str);
                *(p[5]) = in_str.length();
            } else if (v0==9) {
                string in_str;
                getline(infile, in_str);
                *(p[2]) = stoi(in_str);

            } else if (v0 == 10) {
                break;
            } else if (v0==11) {
                char* p_addr = (char*) p[4];
                outfile << *p_addr;
            } else if (v0==12) {
                string in_str;
                getline(infile, in_str);
                char *s_addr = (char*) *(p[2]);
                *s_addr = in_str[0];
            } else if (v0 == 13) {
                char* file_addr = (char*) p[4];
                string file_name = "";
                while (*file_addr != '0') {
                    //Maybe troublesome
                    file_name += *file_addr++;
                }
            }
        }
        else if (instruction.substr(0,6)=="000000"){
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string rd = instruction.substr(16,5);
            string shamt = instruction.substr(21,5);
            int funct = binaryToDecimal( instruction.substr(26) );

            if (funct==32) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                add(prd,prs,prt);
            } else if (funct==33) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                addu(prd,prs,prt);
            } else if (funct==36) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                _and(prd,prs,prt);
            } else if (funct==26) {
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                _div(prs,prt,p[33],p[32]);
            } else if (funct==27) {
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                divu(prs,prt,p[33],p[32]);
            } else if (funct==24) {
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                mult(prs,prt,p[33],p[32]);
            } else if (funct==25) {
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                mulu(prs,prt,p[33],p[32]);
            } else if (funct==2) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                mul(prd,prs,prt);
            } else if (funct==39) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                *prd = ~(*prs | *prt);
            } else if (funct==37) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                *prd = (*prs|*prt);
            } else if (funct==0) {
                int *prd = p[binaryToDecimal(rd)];
                int *prt = p[binaryToDecimal(rt)];
                int shift = binaryToDecimal(shamt);

                string result = extendZero( decimalToBinary(*prt), REG_SIZE );
                result = result.substr(shift);
                for (int i = 0; i < shift; i++) {
                    result += "0";
                }
                *prd = binaryToDecimal(result);
            } else if (funct==4) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                string result;
                if (*prs >= 0) {
                    result = extendZero( decimalToBinary(*prs),32);
                } else {
                    result = extendOne( twoComplement( decimalToBinary(-(*prs))),32);
                }
                int shift = binaryToDecimal(shamt);
                string str = extendZero( decimalToBinary(*prt),32);
                str = str.substr(shift);

                for (int i = 0; i < shift ; i++) {
                    str += "0";
                }
                *prd = binaryToDecimal(str);
            } else if (funct==35) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                *prd = abs(*prs) - abs(*prt);
            } else if (funct==34) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                *prd = *prs - *prt;
            } else if (funct==38) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                *prd = *prs ^ *prt;
            } else if (funct==42) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                if (*prs < *prt) *prd = 1;
                else *prd = 0;
            } else if (funct==43) {
                int *prd = p[binaryToDecimal(rd)];
                int *prs = p[binaryToDecimal(rs)];
                int *prt = p[binaryToDecimal(rt)];
                if (abs(*prs) < abs(*prt)) *prd = 1;
                else *prd = 0;
            } else if (funct==16) {
                int *prd = p[binaryToDecimal(rd)];
                int *hi = p[32];
                *prd = *hi;
            } else if (funct==18) {
                int *prd = p[binaryToDecimal(rd)];
                *prd = *(p[33]);
            } else if (funct==17) {
                int *prs = p[binaryToDecimal(rs)];
                * p[32] = *prs;
            } else if (funct==19) {
                int *prs = p[binaryToDecimal(rs)];
                * p[33] = *prs;
            } else if (funct==8) {
                int *prs = p[binaryToDecimal(rs)];
                num_line = *prs;
            }
        }
        else if (binaryToDecimal(instruction.substr(0,6)) == 28) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string rd = instruction.substr(16,5);
            //int *prd = p[binaryToDecimal(rd)];
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            string shamt = instruction.substr(21,5);
            int funct = binaryToDecimal( instruction.substr(26) );

            if (funct==0) {
                madd(prs,prt,p[33],p[32]);
            } else if (funct==1) {
                maddu(prs,prt,p[33],p[32]);
            } else if (funct==4) {
                msub(prs,prt,p[33],p[32]);
            } else if (funct==5) {
                msubu(prs,prt,p[33],p[32]);
            }
        }

        else if (instruction.substr(0,6) == "001000") {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            //*prs =
            *prt = *prs + imm_int;
        } else if (instruction.substr(0, 6) == "001001") {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            *prs = abs(*prs);
            int imm_int = binaryToDecimal(imm);
            addiu(prt,prs,imm_int);
        }
        else if (binaryToDecimal(instruction.substr(0,6))==12) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            *prt = *prs & imm_int;
        } else if (binaryToDecimal(instruction.substr(0,6))==13) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int =-binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            *prt = *prs | imm_int;
        } else if (binaryToDecimal(instruction.substr(0,6))==14) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            *prt = *prs ^ imm_int;
        } else if (binaryToDecimal(instruction.substr(0,6))==15) {
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            string s = imm + "0000000000000000";
            int *prt = p[binaryToDecimal(rt)];
            int store;
            if (s[0] == '1') {
                store = -binaryToDecimal( twoComplement(imm) );
            } else store = binaryToDecimal(imm);
            *prt = store;
        } else if (binaryToDecimal(instruction.substr(0,6))==10) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            if(*prs < imm_int) *prt = 1;
            else *prt = 0;
        } else if (binaryToDecimal(instruction.substr(0,6))==11) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int = binaryToDecimal(imm);
            if(*prs < imm_int) *prt = 1;
            else *prt = 0;

        } else if (binaryToDecimal(instruction.substr(0,6))==4) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            if (*prs == *prt) {
                num_line += imm_int;
            }

        } else if (binaryToDecimal(instruction.substr(0,6))==32) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int = binaryToDecimal(imm);
            char *naddr = (char *) (*prs + imm_int + BASE_ADDR);
            char *rtchar = (char*) prt;
            *rtchar = *naddr;

        } else if (binaryToDecimal(instruction.substr(0,6))==6) {
            string rs = instruction.substr(6,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            if (*prs <= 0 ) {
                num_line += imm_int;
            }

        } else if (binaryToDecimal(instruction.substr(0,6))==43) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            char * base_addr = (char*) (*prs + BASE_ADDR);
            int *new_addr = (int*) (base_addr + imm_int);
            *new_addr = *prt;
        } else if (binaryToDecimal(instruction.substr(0,6))==40) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            char * base_addr = (char*) (*prs + BASE_ADDR);
            int *new_addr = (int*) (base_addr + imm_int);
            string _str = extendZero( decimalToBinary(*prt),32);
            string _str_ = _str.substr(24);
            int keep = binaryToDecimal(_str_);
            *new_addr = (char) keep;

        }else if (binaryToDecimal(instruction.substr(0,6))==38) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            char *rt_s = (char*) prt + imm_int;
            char *eff_addr = (char*)(*prs + imm_int + BASE_ADDR);
            int high = (uintptr_t) eff_addr%4;
            int start = (uintptr_t) eff_addr/4*4;
            char *read = (char*) start;
            for (int i = high; i < 4;i++){
                *rt_s = *(read+i);
                rt_s += 1;
            }
        } else if (binaryToDecimal(instruction.substr(0,6))==34) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            char * rt_storing = (char*) prt;
            char * effect_addr = (char*)(*prs + imm_int + BASE_ADDR);
            int low_part_num =(uintptr_t) effect_addr % 4;
            for (int i = low_part_num; i >= 0; i--) {
                *(rt_storing + i) = *(effect_addr + i);
            }
        } else if (binaryToDecimal(instruction.substr(0,6))==37) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            short * new_address = (short*) (*prs + imm_int + BASE_ADDR);
            string half_word_str = "0000000000000000" + decimalToBinary(*new_address);
            int new_int = binaryToDecimal(half_word_str);
            *prt = new_int;
        } else if (binaryToDecimal(instruction.substr(0,6))==35) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            char * addr_rs = (char*) (*prs + BASE_ADDR);
            int * new_addr = (int *) (addr_rs + imm_int);
            *prt = *new_addr;

        } else if (binaryToDecimal(instruction.substr(0,6))==5) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);
            if(*prs != *prt) num_line = num_line + imm_int;
        } else if (binaryToDecimal(instruction.substr(0,6))==2) {
            string target = instruction.substr(6);
            int tar = binaryToDecimal(target);
            num_line = tar - 1048577;

        } else if (binaryToDecimal(instruction.substr(0,6))==3) {
            string target = instruction.substr(6);
            int *ra = p[31];
            *ra = num_line;
            int tar = binaryToDecimal(target);
            num_line = tar - 1048577;
        } else if (binaryToDecimal(instruction.substr(0,6))==36) {
            string rs = instruction.substr(6,5);
            string rt = instruction.substr(11,5);
            string imm = instruction.substr(16);
            int *prs = p[binaryToDecimal(rs)];
            int *prt = p[binaryToDecimal(rt)];
            int imm_int;
            if (imm[0] == '1') {
                imm_int = -binaryToDecimal( twoComplement(imm) );
            } else imm_int = binaryToDecimal(imm);

            char * new_addr = (char *) (*prs + imm_int + BASE_ADDR);
            int byte_i = (int) *new_addr;
            string byte_s = extendZero( decimalToBinary(byte_i),8);
            string combine_str = "000000000000000000000000" + byte_s;
            int combine_int = binaryToDecimal(combine_str);
            char * rt_char = (char*) prt;
            *rt_char = combine_int;
        }

    }
}


int main(int argc, char** argv)
{
/*
    string MIPS_file = "D:/CUHKsz/2021/spring/CSC3050/project/project1/"
                       "simulator-samples/memcpy-hello-world.asm";
    string infile_name = "D:/CUHKsz/2021/spring/CSC3050/project/project1/"
                         "simulator-samples/memcpy-hello-world.in";
    string outfile_name = "D:/CUHKsz/2021/spring/CSC3050/project/project1/"
                          "test.txt";
*/

    ifstream input_file;
    ifstream mips_file;
    ofstream output_file;

    mips_file.open(argv[1]);
    input_file.open(argv[2]);
    output_file.open(argv[3]);


    output_file << "Assembled machine codes: " << endl;
    vector<string> binary_instruction;
    in_out_file(argv[1], binary_instruction, output_file);

    output_file << "Assembling finished. Simulation started..." << endl;
    //int a = stoi("111");

    // 32 registers + hi and lo
    int* *reg_p = new int* [REG_SIZE+2];

    for (int j = 0; j < REG_SIZE+2; j++) {
        reg_p[j] = new int;
        *(reg_p[j]) = 0;
    }

    //reg_p[29] = p_text + SIZE;
    /*-----Memory & Register Simulation----*/

    // Text segment processing
    for (int i = 0; i < signed(binary_instruction.size()); i++) {
        string machine_code = binary_instruction[i];
        //cout << machine_code << endl;
        int decimal_code = binaryToDecimal(machine_code);
        int *mp = p_text + i;
        *mp = decimal_code;
    }

    // Data segment processing
    string line;
    bool indiactor = false;
    int *mp = p_data;
    map<string, Data> data_map;


    while (getline(mips_file, line)) {
        string _name, _content = "", _type;

        if (line.substr(0,5) == ".data") {
            indiactor = true;
            continue;
        }
        else if (line.substr(0,5) == ".text") indiactor = false;
        // Cut off redundent data
        if (indiactor) {
            line = cutSpace( cutComments(line) );
            // If it's empty, we do nothing
            if (line.length() == 0) continue;
            int name_i = line.find(':',0);
            _name = line.substr(0,name_i);

            bool is_asciiz = false;
            int type_i = line.find('.',name_i);

            if (line.substr(type_i+1,5) == "ascii") {
                _type = "A";
                if (line.substr(type_i+6,1) == "z") is_asciiz = true;
                if (!is_asciiz) {
                    _content = line.substr(type_i+7,line.length()-type_i-7);
                } else _content = line.substr(type_i+8,line.length()-type_i-8);

            }
            else if (line.substr(type_i+1,1) == "w") {
                _type = "W";
                for (int i = line.length()-1; i>= 0; i--) {
                    char ch = line[i];
                    if (ch == ' ' || ch == '\t') continue;
                    // When we encounter ",", append a "|" for later tokenization
                    if (ch == ',') _content = "|" + _content;
                    if ((int) ch >= 48 && (int) ch <= 57) {
                        _content = line[i] + _content;
                    }
                }
            }
            Data data;
            //cout << "yyy" ;
            /* save for word */
            if (_type == "W") {
                data.int_addr = mp;
                data.type = "W";
                data_map.insert({_name,data});
                // use vector to store the contents
                vector<string> data_str;
                string data_section = "";
                for (unsigned int i = 0; i < _content.length(); ++i) {
                    if (_content[i] == '|') {
                        data_str.push_back(data_section);
                        data_section = "";
                        continue;
                    }
                    data_section += _content.substr(i,1);
                }
                int num_check = _content.find("|");
                if (num_check < 0) data_str.push_back(_content);
                int check_last = _content.find_last_of("|");
                if (check_last > 0) data_str.push_back(_content.substr(check_last+1));

                for (unsigned int j = 0; j < data_str.size(); j++) {
                    *mp = atof(data_str[j].c_str());
                    mp += 1;
                }
            }
            if (_type == "A") {
                // string transformation, type cast to char
                char* mem_addr = (char*) mp;
                char* mem_cpy = mem_addr;
                data.type = "A";
                data.char_addr = mem_addr;
                data.length = _content.length();

                for (int i = 0; i < data.length; i++) {
                    if (_content[i] == '\\') data.length--;
                }

                data_map.insert({_name, data});
                for (unsigned int i = 0; i < _content.length(); i++) {
                    if (_content[i] == '\\') {
                        *mem_addr = '\n'; ++i;
                    }
                    *mem_addr = _content[i];
                    mem_addr += 1;
                }

                if (is_asciiz) {
                    *mem_addr = '\0';
                    mem_addr += 1;
                }
                // Memory address increasing
                if ((mem_addr - mem_cpy)%4==0) mp = (int*) mem_addr;
                // After transformation, we move to next position
                else mp += ((uintptr_t) mem_addr - (uintptr_t) mem_cpy) / 4 + 1;

            }
        }
    }
    output_file << "Simulation finished."<< endl;

    execution(binary_instruction, reg_p, input_file, output_file);

    output_file << "execution finished";

    input_file.close();
    mips_file.close();
    output_file.close();


    return 0;
}
