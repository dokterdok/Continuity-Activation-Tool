//
//  main.cpp
//  findString
//
//  Created by Jan (sysfloat) on 2015-06-21.
//  Copyright (c) 2015 Jan. All rights reserved.
//  MIT License
//

#include <iostream>
#include <string>
#include <fstream>

using namespace std;

size_t len;

char* readFile(const char *name);
int findString(const char *fileContentPtr, const char *stringToFind);

int main(int argc, const char * argv[]) {
    if (argc < 3){
        std::cerr << "Usage: " << "stringFile FILENAME STRING" << std::endl;
        return 1;
    }
    char *fileContentPtr = readFile(argv[1]);
    const char *stringToFind = argv[2];
    findString(fileContentPtr, stringToFind);
    return 0;
}

char* readFile(const char *name)
{
    ifstream file(name);
    file.seekg(0, ios::end);
    len = file.tellg();
    char *ret = new char[len];
    file.seekg(0, ios::beg);
    file.read(ret, len);
    file.close();
    return ret;
}

int findString(const char *fileContentPtr, const char *stringToFind) {
    string strFind(stringToFind, stringToFind + strlen(stringToFind));
    string strContent(fileContentPtr, fileContentPtr + len);
    size_t n = strContent.find(strFind);
    while(n != string::npos) {
        printf("%lx ", n);
        size_t pos = n;
        while(strContent[pos] != 0x00)
        {
            printf("%c", strContent[pos]);
            pos++;
        }
        printf("\n");
        n = strContent.find(strFind, n+1);
    }
    return 0;
}