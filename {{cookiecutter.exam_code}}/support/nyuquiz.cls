\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{nyuquiz}
%
% Class options: allow selecting whether to use the NYU font bundle via
% fontspec (system-installed fonts) or fall back to the free fonts
% (charter + montserrat). By default we use the free fonts. Pass the
% option `nyufonts' to enable the fontspec-based NYU fonts; pass
% `freefonts' to explicitly select the free fonts (this is the default).
\newif\ifnyuquiz@usenyufonts
\nyuquiz@usenyufontsfalse % default -> use free fonts
\DeclareOption{nyufonts}{\nyuquiz@usenyufontstrue}
\DeclareOption{freefonts}{\nyuquiz@usenyufontsfalse}

% Option: circlechoices (default) or nocirclechoices
\newif\ifnyuquiz@circlechoices
\nyuquiz@circlechoicestrue
\DeclareOption{circlechoices}{\nyuquiz@circlechoicestrue}
\DeclareOption{nocirclechoices}{\nyuquiz@circlechoicesfalse}


% Pass any unknown options on to the exam class
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{exam}}
\ProcessOptions\relax
\LoadClass[11pt]{exam}

% metadata
\NewCommandCopy{\old@title}{\title}
\RenewDocumentCommand{\title}{O{#2}m}{
    \gdef\@short@title{#1}
    \old@title{#2}
}
\NewDocumentCommand{\course}{O{#2}m}{
    \gdef\@short@course{#1}
    \gdef\@course{#2}
}
\RequirePackage{amsmath,
   amssymb,
   changepage,%\checkoddpage,\ifoddpage
   color,
   comment,
   graphicx,
   multicol,
   pdfpages,
   tikz,
   xstring,
}
\RequirePackage{xpatch}
\RequirePackage{eso-pic}
\RequirePackage{graphicx}
\RequirePackage{etoolbox}
\newsavebox{\logobox}
\savebox{\logobox}{\includegraphics[]{nyu_short_black}}
\renewcommand{\maketitle}{
    \noindent\parbox{\textwidth}{%
    \sffamily\color{UltraViolet}%
    \Large\@author
    \hfill\@title
    \hfill\@date}
    {\color{UltraViolet}\hrule\bigskip}
    \AddToShipoutPictureBG*{%
    \AtPageUpperLeft{%
      \raisebox{-1.5\ht\logobox}{\hspace{0.5\ht\logobox}\usebox{\logobox}}
      }%
    }
}

\newcommand{\student@name}{}
\newcommand{\student@id}{}
\newcommand{\studentnamestyle}{\sffamily\Large\color{DeepViolet}}
\newcommand{\studentidstyle}{\sffamily\Large\color{DeepViolet}}
\NewDocumentCommand{\setstudentname}{m}{\gdef\student@name{#1}}
\NewDocumentCommand{\setstudentid}{m}{\gdef\student@id{#1}}
\newcommand{\insertstudentname}{\studentnamestyle\student@name}
\newcommand{\insertstudentid}{\studentidstyle\student@id}
\newcommand{\insertcodefield}{\relax}

\newcommand{\insertidfields}{
{\setlength{\parindent}{0pt}%
  \begin{minipage}[b]{8cm}
      \hfill\fbox{
      \begin{minipage}[b][1.1cm+3ex][t]{0.95\textwidth}
          Full Name:\vfill
          \insertstudentname
      \end{minipage}
  }\hfill\vspace{5ex}
  \end{minipage}
  \begin{minipage}[b]{8cm}
      \hfill\fbox{
      \begin{minipage}[b][1.1cm+3ex][t]{0.95\textwidth}
          NetID:\vfill
          \insertstudentid
      \end{minipage}
  }\hfill\vspace{5ex}
  \end{minipage}
  \hspace*{\fill}
\bigskip
}}

%% large print option
\newif\iflargeprint\largeprintfalse
\AtEndPreamble{
  \iflargeprint
    \RequirePackage[fontsize=16pt]{scrextend}
  \fi
}
\AtBeginDocument{
  \iflargeprint
    \pgfplotsset{execute at begin axis={
        \pgfplotsset{normalsize}
    }}
    % \AMCboxStyle{shape=oval,down=1mm,size=2.5ex}
    % \AMCopenOpts{lines=12,framerule=0pt}    
    % \AddToHook{cmd/insertcodefield/before}{\bgroup\AMCboxStyle{size=2.0ex}}
    % \AddToHook{cmd/insertcodefield/after}{\egroup\AddToHook{env/question/end}[largeprint]{\clearpage}}
  \fi
}
%% end large print option

\AtEndPreamble{
  \ifprintanswers
    \AddToHook{cmd/studentnamestyle/after}{\Huge\color{Magenta}}
    \setstudentname{Solutions}
  \fi
}

\RequirePackage{xcolor-nyu22}
\RequirePackage{iftex}
% Font selection: if class option `fontspec' is passed and the engine
% supports fontspec (XeLaTeX or LuaLaTeX), load fontspec and user fonts.
% Otherwise fall back to the free fonts (charter + montserrat).
\ifnyuquiz@usenyufonts
    % Detect XeTeX or LuaTeX using the `iftex' package; it provides
    % the primitive conditional \iftutex which is true for both XeTeX
    % and LuaTeX.
    \iftutex
        \RequirePackage{fontspec}
        \setmainfont{Frank Ruhl Libre}[
            ItalicFont=*,
            ItalicFeatures={FakeSlant},
            SmallCapsFont={Latin Modern Roman Caps}
        ]
        \setsansfont{NYU Perstare}[
        FontFace={l}{n}{* Light},
        FontFace={l}{it}{* Light Italic},
        FontFace={sb}{n}{* Medium},
        FontFace={sb}{it}{* Medium Italic},
        FontFace={b}{n}{* Bold},
        FontFace={b}{it}{* Bold Italic},
        UprightFont=* Regular,
        BoldFont=* Medium,
        ItalicFont=* Italic,
        BoldItalicFont=* Medium Italic,
        SmallCapsFont=Montserrat-Medium.otf, SmallCapsFeatures={Letters=SmallCaps},
        BoldFeatures={SmallCapsFont=Montserrat-Bold.otf},
        ]
    \else
    % pdfLaTeX cannot use fontspec; warn and fall back
    \PackageWarning{nyuexam}{Option `nyufonts' requested but fontspec is only available with XeTeX/LuaTeX. Falling back to charter + montserrat.}
        \RequirePackage{charter}
        \RequirePackage{montserrat}
    \fi
\else
    % Default free fonts for pdfLaTeX and others
    \RequirePackage{charter}
    \RequirePackage{montserrat}
\fi
% \headrule% head rule across non-cover pages
% \coverrunningheadrule% head rule non-first cover pages
\xpatchcmd{\run@fullhead}{\hrule}{\color{NyuViolet}\hrule}{}{\PatchFailed}
\xpatchcmd{\covrun@fullhead}{\hrule}{\color{NyuViolet}\hrule}{}{\PatchFailed}
\xpatchcmd{\@fullhead}{\hrule}{\color{NyuViolet}\hrule}{}{\PatchFailed}

% put logo on first cover page, no other header
\coverfirstpageheader{\begin{tikzpicture}[remember picture, overlay]
    \draw (current page.north west) ++ (0.25in,-0.25in) 
        node[anchor=north west] (logo)
        {\includegraphics[width=2.5in]{courant_short_black}};
  \end{tikzpicture}%
}{}{}

\RequirePackage{markversion}% Sets \VCRevisionMod and provides \UseVersionOf

% Set footers on non-cover pages
\footer%
    {\UseVersionOf{\jobname.tex}, \UseDateOf{\jobname.tex}}
    {\thepage/\numpages}
    {Revision \VCRevisionMod}


\newcommand{\headerfont}{\sffamily\color{DeepViolet}}
% \header% all non-cover pages
%     {\headerfont\@short@course}
%     {\headerfont\@short@title}
%     {\headerfont\@date}
%     \coverrunningheader% cover pages except the first cover page
%     {\run@lhead}
%     {\run@chead}
%     {\run@rhead}
% \footer% all non-cover pages
% %    {\UseVersionOf{\jobname.tex}, \UseDateOf{\jobname.tex}}
%     {}
%     {\thepage/\numpages}
% %    {Revision \VCRevisionMod}
%     {}
% \coverfooter% footer on cover pages only
%     {\run@lfoot}
%     {}
%     {\run@rfoot}

% Customize the styling of the optional argument to \answerline exam.cls
% uses the \CorrectChoice@Empasis token list for this.
\newcommand\CorrectAnswerStyle[1]{%
  \def\CorrectAnswer@Style{#1}%
}
\CorrectAnswerStyle{\everymath{\displaystyle}\CorrectChoice@Emphasis}
\xpatchcmd{\answerline}{\CorrectChoice@Emphasis}{\CorrectAnswer@Style}{}{\PatchFailed}

\shadedsolutions % needs color package

\ifnyuquiz@circlechoices
  % multiple choice circles, needs tikz package
  %:TODO make more like AMC
  \tikzset{circled choice/.style={
      draw=MediumViolet2,
      shape=circle,
      minimum size=1.25em,
      inner sep=0pt,
      thick,
      text=LightViolet1,
      font=\sffamily
  }}
  \newcommand*\circled[1]{\tikz[baseline=(char.base)]{%
          \node[circled choice] (char) {#1};}}
  \renewcommand\choicelabel{\circled{\Alph{choice}}}
  \CorrectChoiceEmphasis{% 
      	\tikzset{circled choice/.append style={fill=NyuViolet}}%
      \color{NyuViolet}%
      \bfseries}
  \checkboxchar{\circled{\phantom{A}}}
  \checkedchar{\tikzset{circled choice/.append style={fill=NyuViolet}}\circled{\phantom{A}}}
  \renewcommand{\questionshook}{%
      \settowidth{\leftmargin}{0pt}}
  \renewcommand{\choiceshook}{%
    \settowidth{\leftmargin}{\circled{W}.\hskip\labelsep\hskip 0em}%
    \setlength{\itemsep}{2\itemsep}}
  \renewcommand{\checkboxeshook}{%
    \settowidth{\leftmargin}{\circled{W}.\hskip\labelsep\hskip 0em}
    \setlength{\itemsep}{2\itemsep}}
\fi

\setlength\linefillheight{36pt}
\colorfillwithlines
\colorlet{FillWithLinesColor}{MediumViolet2}


\newenvironment{instructions}{\noindent\sffamily\relax}{}



\setlength\answerclearance{0.5ex}

% strongly encourage a page break before each question
% h/t me https://tex.stackexchange.com/a/705383/1402
\appto{\questionshook}{\preto{\question}{\filbreak}}



\newcommand{\exammsgpageisblank}{(This page intentionally left blank. You may use it for scratch work.)}
\newcommand{\examblankpage}{
    \begin{center}
        \exammsgpageisblank    
    \end{center}
    \clearpage
}
\newcommand{\examcleardoublepage}{%
    \clearpage%
    \checkoddpage%
    \ifoddpage%
        \else
        \examblankpage
    \fi
}

% Some definitions needed to show students how to shade the answers in multiple choice
\newcommand*\samplecirc[1]{%
    \begin{tikzpicture}[baseline=(C.base)]
        \node[circled choice] (C) {#1};
\end{tikzpicture}}
\newcommand*\samplecircSoln[1]{%
    \begin{tikzpicture}[baseline=(C.base)]
        {\node[circled choice,fill=DarkGray] (C) {#1};} 
\end{tikzpicture}}

% Print the number of questions in a grading range in words.
% * Requires the fmtcount package
% * No h@ckery but still requires knowing the internals of \numqinrange.
% * fmtcount has more options like \Numberstring and \NUMBERstring
\RequirePackage{fmtcount}
\let\numstrqinrange\numqinrange
\patchcmd{\numstrqinrange}{\arabic}{\numberstring}{}{\PatchFailed}

\newenvironment{hint}{\par\noindent\textit{Hint.}}{}

% Make all math display style
\RequirePackage{everyhook}
\PushPostHook{math}{\displaystyle}

\RequirePackage{nicefrac}
\RequirePackage{cancel}
\RequirePackage{enumitem}
\RequirePackage{multicol}