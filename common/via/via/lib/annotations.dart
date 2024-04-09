const context = ContextAnnotation();
const initialState = InitialStateAnnotation();
const fatalState = FatalStateAnnotation();

class States {
  final Type context;
  const States(this.context);
}

class ContextAnnotation {
  const ContextAnnotation();
}

class InitialStateAnnotation {
  const InitialStateAnnotation();
}

class FatalStateAnnotation {
  const FatalStateAnnotation();
}
