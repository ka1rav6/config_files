Error: Cannot call impure function during render

`Date.now` is an impure function. Calling an impure function can produce unstable results that update unpredictably when the component happens to re-render. (https://react.dev/reference/rules/components-and-hooks-must-be-pure#components-and-hooks-must-be-idempotent).

/home/kairav/dev/byld/college-lms/mvp/frontend/src/components/AssignmentCard.tsx:42:36
  40 |     description,
  41 | }: AssignmentCardProps) {
> 42 |     const [now, setNow] = useState(Date.now());
     |                                    ^^^^^^^^^^ Cannot call impure function
  43 |
  44 |     useEffect(() => {
  45 |         const interval = setInterval(() => {